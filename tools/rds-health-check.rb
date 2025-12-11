#!/usr/bin/env ruby
# frozen_string_literal: true

# RDS Health Check - Monitor RDS instance CPU and memory utilization
#
# Usage:
#   ./tools/rds-health-check.rb [db-instance-identifier]
#
# Options:
#   --watch N           Refresh every N seconds (default: 60)
#   --json              Output in JSON format
#   --threshold N       CPU/memory threshold for warnings (default: 80)
#   --extended-memory   Show extended memory-related metrics (swap, network, disk queue)
#
# Examples:
#   ./tools/rds-health-check.rb                    # Check default instance
#   ./tools/rds-health-check.rb my-db-instance     # Check specific instance
#   ./tools/rds-health-check.rb --watch 30         # Refresh every 30 seconds
#   ./tools/rds-health-check.rb --json             # JSON output
#   ./tools/rds-health-check.rb --extended-memory  # Show extended memory metrics

require 'aws-sdk-rds'
require 'aws-sdk-cloudwatch'
require 'optparse'
require 'json'

class RDSHealthCheck
  def initialize(options = {})
    @rds = Aws::RDS::Client.new(region: options[:region] || ENV['AWS_REGION'] || 'us-west-2')
    @cloudwatch = Aws::CloudWatch::Client.new(region: options[:region] || ENV['AWS_REGION'] || 'us-west-2')
    @options = options
  end

  def check_instance(db_instance_identifier = nil)
    # Get DB instance info
    db_instance_identifier ||= detect_default_instance

    unless db_instance_identifier
      puts "Error: No DB instance identifier provided and couldn't detect default"
      puts "Usage: #{$0} [db-instance-identifier]"
      exit 1
    end

    begin
      instance = @rds.describe_db_instances(db_instance_identifier: db_instance_identifier).db_instances.first
    rescue Aws::RDS::Errors::DBInstanceNotFound
      puts "Error: DB instance '#{db_instance_identifier}' not found"
      exit 1
    end

    # Get CloudWatch metrics
    metrics = fetch_metrics(db_instance_identifier)

    # Build result
    result = {
      instance_identifier: instance.db_instance_identifier,
      instance_class: instance.db_instance_class,
      engine: "#{instance.engine} #{instance.engine_version}",
      status: instance.db_instance_status,
      storage: {
        allocated_gb: instance.allocated_storage,
        storage_type: instance.storage_type,
        iops: instance.iops
      },
      multi_az: instance.multi_az,
      availability_zone: instance.availability_zone,
      endpoint: instance.endpoint&.address,
      metrics: metrics,
      timestamp: Time.now.utc.iso8601
    }

    # Check thresholds
    threshold = @options[:threshold] || 80
    warnings = []
    warnings << "CPU > #{threshold}%" if metrics[:cpu_utilization] && metrics[:cpu_utilization] > threshold
    warnings << "Memory > #{threshold}%" if metrics[:memory_utilization] && metrics[:memory_utilization] > threshold
    warnings << "Connections high" if metrics[:database_connections] && metrics[:database_connections] > 100

    result[:warnings] = warnings unless warnings.empty?

    result
  end

  def fetch_metrics(db_instance_identifier, period: 300)
    end_time = Time.now
    start_time = end_time - 3600 # Last hour

    metrics_to_fetch = [
      { name: 'CPUUtilization', stat: 'Average', unit: 'Percent' },
      { name: 'FreeableMemory', stat: 'Average', unit: 'Bytes' },
      { name: 'DatabaseConnections', stat: 'Average', unit: 'Count' },
      { name: 'ReadLatency', stat: 'Average', unit: 'Seconds' },
      { name: 'WriteLatency', stat: 'Average', unit: 'Seconds' },
      { name: 'ReadIOPS', stat: 'Average', unit: 'Count/Second' },
      { name: 'WriteIOPS', stat: 'Average', unit: 'Count/Second' },
      { name: 'FreeStorageSpace', stat: 'Average', unit: 'Bytes' }
    ]

    # Add extended memory metrics if requested
    if @options[:extended_memory]
      metrics_to_fetch += [
        { name: 'SwapUsage', stat: 'Average', unit: 'Bytes' },
        { name: 'BinLogDiskUsage', stat: 'Average', unit: 'Bytes' },
        { name: 'NetworkReceiveThroughput', stat: 'Average', unit: 'Bytes/Second' },
        { name: 'NetworkTransmitThroughput', stat: 'Average', unit: 'Bytes/Second' },
        { name: 'DiskQueueDepth', stat: 'Average', unit: 'Count' },
        { name: 'ReadThroughput', stat: 'Average', unit: 'Bytes/Second' },
        { name: 'WriteThroughput', stat: 'Average', unit: 'Bytes/Second' }
      ]
    end

    result = {}

    metrics_to_fetch.each do |metric_def|
      begin
        response = @cloudwatch.get_metric_statistics(
          namespace: 'AWS/RDS',
          metric_name: metric_def[:name],
          dimensions: [
            { name: 'DBInstanceIdentifier', value: db_instance_identifier }
          ],
          start_time: start_time,
          end_time: end_time,
          period: period,
          statistics: [metric_def[:stat]],
          unit: metric_def[:unit]
        )

        if response.datapoints.any?
          latest = response.datapoints.max_by(&:timestamp)
          value = latest.send(metric_def[:stat].downcase)

          # Format based on metric type
          case metric_def[:name]
          when 'CPUUtilization'
            result[:cpu_utilization] = value.round(2)
          when 'FreeableMemory'
            result[:freeable_memory_mb] = (value / 1024 / 1024).round(2)
            # Calculate percentage if we have total memory (approximate from instance class)
            result[:memory_utilization] = estimate_memory_utilization(value)
          when 'DatabaseConnections'
            result[:database_connections] = value.round(0)
          when 'ReadLatency'
            result[:read_latency_ms] = (value * 1000).round(2)
          when 'WriteLatency'
            result[:write_latency_ms] = (value * 1000).round(2)
          when 'ReadIOPS'
            result[:read_iops] = value.round(2)
          when 'WriteIOPS'
            result[:write_iops] = value.round(2)
          when 'FreeStorageSpace'
            result[:free_storage_gb] = (value / 1024 / 1024 / 1024).round(2)
          when 'SwapUsage'
            result[:swap_usage_mb] = (value / 1024 / 1024).round(2)
          when 'BinLogDiskUsage'
            result[:binlog_disk_usage_mb] = (value / 1024 / 1024).round(2)
          when 'NetworkReceiveThroughput'
            result[:network_receive_mbps] = (value / 1024 / 1024).round(2)
          when 'NetworkTransmitThroughput'
            result[:network_transmit_mbps] = (value / 1024 / 1024).round(2)
          when 'DiskQueueDepth'
            result[:disk_queue_depth] = value.round(2)
          when 'ReadThroughput'
            result[:read_throughput_mbps] = (value / 1024 / 1024).round(2)
          when 'WriteThroughput'
            result[:write_throughput_mbps] = (value / 1024 / 1024).round(2)
          end
        end
      rescue => e
        warn "Warning: Failed to fetch #{metric_def[:name]}: #{e.message}" unless @options[:json]
      end
    end

    result
  end

  def estimate_memory_utilization(freeable_memory_bytes)
    # This is approximate - actual total memory depends on instance class
    # For more accurate results, you'd need to track the total memory separately
    # Assuming typical instance has 8GB (can be adjusted)
    total_memory_bytes = 8 * 1024 * 1024 * 1024
    used_memory = total_memory_bytes - freeable_memory_bytes
    utilization = (used_memory.to_f / total_memory_bytes * 100).round(2)
    [0, [100, utilization].min].max # Clamp between 0-100
  end

  def detect_default_instance
    # Try to detect from common patterns
    # 1. Check environment variable
    return ENV['DB_INSTANCE_IDENTIFIER'] if ENV['DB_INSTANCE_IDENTIFIER']

    # 2. Try to extract from CloudFormation config
    cf_path = File.join(File.dirname(__FILE__), '..', 'cf', 'everything2-production.json')
    if File.exist?(cf_path)
      begin
        cf_content = File.read(cf_path)
        require 'json'
        cf_json = JSON.parse(cf_content)

        # Find DBInstance resource
        cf_json['Resources']&.each do |_key, resource|
          if resource['Type'] == 'AWS::RDS::DBInstance'
            db_id = resource['Properties']&.dig('DBInstanceIdentifier')
            return db_id if db_id
          end
        end
      rescue => e
        warn "Warning: Couldn't parse CloudFormation config: #{e.message}" unless @options[:json]
      end
    end

    # 3. Try to list instances and pick the first one
    begin
      instances = @rds.describe_db_instances.db_instances
      return instances.first.db_instance_identifier if instances.any?
    rescue => e
      warn "Warning: Couldn't list DB instances: #{e.message}" unless @options[:json]
    end

    nil
  end

  def format_output(result)
    if @options[:json]
      puts JSON.pretty_generate(result)
    else
      puts "\n" + "=" * 80
      puts "RDS Instance Health Check"
      puts "=" * 80
      puts "Instance:     #{result[:instance_identifier]}"
      puts "Class:        #{result[:instance_class]}"
      puts "Engine:       #{result[:engine]}"
      puts "Status:       #{result[:status]}"
      puts "Multi-AZ:     #{result[:multi_az]}"
      puts "AZ:           #{result[:availability_zone]}"
      puts "Endpoint:     #{result[:endpoint]}"
      puts "-" * 80

      puts "Storage:"
      puts "  Allocated:  #{result[:storage][:allocated_gb]} GB"
      puts "  Type:       #{result[:storage][:storage_type]}"
      puts "  IOPS:       #{result[:storage][:iops]}" if result[:storage][:iops]

      if result[:metrics][:free_storage_gb]
        puts "  Free:       #{result[:metrics][:free_storage_gb]} GB"
      end

      puts "-" * 80
      puts "Metrics (#{result[:timestamp]}):"

      if result[:metrics][:cpu_utilization]
        cpu_bar = create_bar(result[:metrics][:cpu_utilization], 100)
        puts "  CPU:        #{result[:metrics][:cpu_utilization]}% #{cpu_bar}"
      end

      if result[:metrics][:memory_utilization]
        mem_bar = create_bar(result[:metrics][:memory_utilization], 100)
        puts "  Memory:     #{result[:metrics][:memory_utilization]}% #{mem_bar}"
        puts "              (#{result[:metrics][:freeable_memory_mb]} MB free)"
      end

      if result[:metrics][:database_connections]
        puts "  Connections: #{result[:metrics][:database_connections]}"
      end

      if result[:metrics][:read_latency_ms]
        puts "  Read Latency:  #{result[:metrics][:read_latency_ms]} ms"
      end

      if result[:metrics][:write_latency_ms]
        puts "  Write Latency: #{result[:metrics][:write_latency_ms]} ms"
      end

      if result[:metrics][:read_iops]
        puts "  Read IOPS:     #{result[:metrics][:read_iops]}"
      end

      if result[:metrics][:write_iops]
        puts "  Write IOPS:    #{result[:metrics][:write_iops]}"
      end

      # Extended memory metrics
      if @options[:extended_memory]
        puts "-" * 80
        puts "Extended Memory Metrics:"

        if result[:metrics][:swap_usage_mb]
          swap_warning = result[:metrics][:swap_usage_mb] > 0 ? " ⚠️  SWAPPING!" : ""
          puts "  Swap Usage:          #{result[:metrics][:swap_usage_mb]} MB#{swap_warning}"
        end

        if result[:metrics][:binlog_disk_usage_mb]
          puts "  BinLog Disk Usage:   #{result[:metrics][:binlog_disk_usage_mb]} MB"
        end

        if result[:metrics][:network_receive_mbps]
          puts "  Network Receive:     #{result[:metrics][:network_receive_mbps]} MB/s"
        end

        if result[:metrics][:network_transmit_mbps]
          puts "  Network Transmit:    #{result[:metrics][:network_transmit_mbps]} MB/s"
        end

        if result[:metrics][:disk_queue_depth]
          queue_warning = result[:metrics][:disk_queue_depth] > 1 ? " ⚠️" : ""
          puts "  Disk Queue Depth:    #{result[:metrics][:disk_queue_depth]}#{queue_warning}"
        end

        if result[:metrics][:read_throughput_mbps]
          puts "  Read Throughput:     #{result[:metrics][:read_throughput_mbps]} MB/s"
        end

        if result[:metrics][:write_throughput_mbps]
          puts "  Write Throughput:    #{result[:metrics][:write_throughput_mbps]} MB/s"
        end

        # Memory analysis
        if result[:metrics][:freeable_memory_mb] && result[:metrics][:swap_usage_mb]
          puts "\nMemory Analysis:"
          puts "  Freeable Memory:     #{result[:metrics][:freeable_memory_mb]} MB"
          puts "  Swap Usage:          #{result[:metrics][:swap_usage_mb]} MB"

          if result[:metrics][:swap_usage_mb] > 100
            puts "  Status: ⚠️  HIGH SWAP - Memory pressure detected"
            puts "  Recommendation: Consider increasing instance size or optimizing queries"
          elsif result[:metrics][:swap_usage_mb] > 0
            puts "  Status: ⚠️  Minor swapping - Monitor for trends"
          else
            puts "  Status: ✓ No swapping detected"
          end
        end
      end

      if result[:warnings]
        puts "-" * 80
        puts "⚠️  WARNINGS:"
        result[:warnings].each do |warning|
          puts "  • #{warning}"
        end
      end

      puts "=" * 80
      puts
    end
  end

  def create_bar(value, max, width: 40)
    filled = (value.to_f / max * width).round
    empty = width - filled

    # Color based on value
    if value > 80
      color = "\e[31m" # Red
    elsif value > 60
      color = "\e[33m" # Yellow
    else
      color = "\e[32m" # Green
    end

    reset = "\e[0m"
    "#{color}#{'█' * filled}#{'░' * empty}#{reset}"
  end

  def watch(db_instance_identifier, interval)
    loop do
      system('clear') unless @options[:json]
      result = check_instance(db_instance_identifier)
      format_output(result)

      unless @options[:json]
        puts "Refreshing every #{interval}s... (Ctrl-C to stop)"
        sleep interval
      else
        break
      end
    end
  end
end

# Parse options
options = {}
db_instance_identifier = nil

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] [db-instance-identifier]"

  opts.on("--watch N", Integer, "Refresh every N seconds") do |n|
    options[:watch] = n
  end

  opts.on("--json", "Output in JSON format") do
    options[:json] = true
  end

  opts.on("--threshold N", Integer, "CPU/memory threshold for warnings (default: 80)") do |n|
    options[:threshold] = n
  end

  opts.on("--extended-memory", "Show extended memory-related metrics") do
    options[:extended_memory] = true
  end

  opts.on("--region REGION", "AWS region (default: us-west-2)") do |region|
    options[:region] = region
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

db_instance_identifier = ARGV[0]

# Run health check
checker = RDSHealthCheck.new(options)

if options[:watch]
  checker.watch(db_instance_identifier, options[:watch])
else
  result = checker.check_instance(db_instance_identifier)
  checker.format_output(result)
end
