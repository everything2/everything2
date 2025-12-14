#!/usr/bin/env ruby
# frozen_string_literal: true

# RDS Sizing Analysis Tool
#
# Analyzes RDS CloudWatch metrics to determine if the instance is right-sized
# and identify potential cost savings opportunities.
#
# Usage:
#   ./tools/rds-sizing-analysis.rb                    # Last 7 days
#   ./tools/rds-sizing-analysis.rb --days 14          # Last 14 days
#   ./tools/rds-sizing-analysis.rb --days 30          # Last 30 days
#
# Evaluates:
#   - CPU utilization (should be 40-70% on average for good sizing)
#   - Memory utilization (should be < 85% to avoid swapping)
#   - IOPS utilization (should be < 80% of provisioned)
#   - Storage utilization and growth rate
#   - Connection count vs max connections
#   - Network throughput
#
# Recommendations:
#   - Instance class changes (e.g., db.t3.medium -> db.t3.small)
#   - Storage optimization (reduce provisioned IOPS if underutilized)
#   - Reserved instance savings estimate

require 'json'
require 'optparse'
require 'open3'
require 'time'

REGION = 'us-west-2'
DB_INSTANCE = 'everything2vpc'

# Current RDS configuration (from CloudFormation)
CURRENT_INSTANCE_CLASS = 'db.t3.medium'
CURRENT_STORAGE_GB = 100
CURRENT_STORAGE_TYPE = 'gp3'
CURRENT_IOPS = 3000

# Pricing (approximate, us-west-2, as of 2025)
INSTANCE_PRICING = {
  'db.t3.micro'   => { on_demand: 0.017, reserved_1yr: 0.011 },
  'db.t3.small'   => { on_demand: 0.034, reserved_1yr: 0.022 },
  'db.t3.medium'  => { on_demand: 0.068, reserved_1yr: 0.044 },
  'db.t3.large'   => { on_demand: 0.136, reserved_1yr: 0.088 },
  'db.t3.xlarge'  => { on_demand: 0.272, reserved_1yr: 0.176 },
  'db.t3.2xlarge' => { on_demand: 0.544, reserved_1yr: 0.352 },
  'db.r6g.large'  => { on_demand: 0.240, reserved_1yr: 0.156 },
  'db.r6g.xlarge' => { on_demand: 0.480, reserved_1yr: 0.312 }
}

STORAGE_PRICING = {
  gp3: { storage_per_gb: 0.115, iops_per_unit: 0.005 }, # Per month
  gp2: { storage_per_gb: 0.115 }
}

options = {
  days: 7,
  profile: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-d", "--days DAYS", Integer, "Number of days to analyze (default: 7)") do |d|
    options[:days] = d
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "This tool analyzes RDS CloudWatch metrics to determine optimal sizing."
    puts "It evaluates CPU, memory, IOPS, storage, and connection metrics to"
    puts "identify cost savings opportunities."
    exit
  end
end.parse!

def aws_cmd(options)
  cmd = ["aws"]
  cmd += ["--profile", options[:profile]] if options[:profile]
  cmd += ["--region", REGION]
  cmd
end

def run_aws(options, *args)
  cmd = aws_cmd(options) + args + ["--output", "json"]
  stdout, stderr, status = Open3.capture3(*cmd)

  unless status.success?
    STDERR.puts "AWS command failed: #{cmd.join(' ')}"
    STDERR.puts stderr unless stderr.empty?
    return nil
  end

  JSON.parse(stdout) rescue stdout
end

def get_metric_statistics(options, metric_name, stat, days)
  end_time = Time.now
  start_time = end_time - (days * 24 * 60 * 60)

  # Use 1-hour periods for better granularity
  period = 3600

  result = run_aws(options, "cloudwatch", "get-metric-statistics",
                   "--namespace", "AWS/RDS",
                   "--metric-name", metric_name,
                   "--dimensions", "Name=DBInstanceIdentifier,Value=#{DB_INSTANCE}",
                   "--start-time", start_time.utc.iso8601,
                   "--end-time", end_time.utc.iso8601,
                   "--period", period.to_s,
                   "--statistics", stat)

  return nil unless result && result['Datapoints']

  result['Datapoints'].sort_by { |dp| dp['Timestamp'] }
end

def calculate_stats(datapoints, stat_key)
  return nil if datapoints.nil? || datapoints.empty?

  values = datapoints.map { |dp| dp[stat_key] }.compact
  return nil if values.empty?

  {
    min: values.min,
    max: values.max,
    avg: values.sum / values.length,
    p95: percentile(values, 95),
    p99: percentile(values, 99)
  }
end

def percentile(values, p)
  sorted = values.sort
  index = (p / 100.0 * sorted.length).ceil - 1
  sorted[[index, 0].max]
end

def format_percent(value)
  "#{value.round(1)}%"
end

def format_bytes(bytes)
  return "0 B" if bytes.nil? || bytes == 0

  units = ['B', 'KB', 'MB', 'GB', 'TB']
  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = units.length - 1 if exp >= units.length

  format("%.2f %s", bytes.to_f / (1024**exp), units[exp])
end

def analyze_cpu(options, days)
  puts "CPU Utilization"
  puts "-" * 60

  cpu_data = get_metric_statistics(options, "CPUUtilization", "Average", days)
  stats = calculate_stats(cpu_data, "Average")

  if stats
    puts "  Average: #{format_percent(stats[:avg])}"
    puts "  Min:     #{format_percent(stats[:min])}"
    puts "  Max:     #{format_percent(stats[:max])}"
    puts "  P95:     #{format_percent(stats[:p95])}"
    puts "  P99:     #{format_percent(stats[:p99])}"
    puts

    # Recommendations
    if stats[:avg] < 20 && stats[:p95] < 40
      puts "  ⚠️  CPU is significantly underutilized (avg #{format_percent(stats[:avg])})"
      puts "      Consider downsizing to a smaller instance class"
    elsif stats[:avg] < 40 && stats[:p95] < 60
      puts "  ℹ️  CPU utilization is low (avg #{format_percent(stats[:avg])})"
      puts "      You may be able to downsize, but monitor during peak times"
    elsif stats[:avg] > 70 || stats[:p95] > 85
      puts "  ⚠️  CPU utilization is high (avg #{format_percent(stats[:avg])}, P95 #{format_percent(stats[:p95])})"
      puts "      Consider upgrading to a larger instance class"
    else
      puts "  ✓ CPU utilization is well-balanced"
    end
  else
    puts "  Error: Could not retrieve CPU metrics"
  end

  puts
  stats
end

def analyze_memory(options, days)
  puts "Memory Utilization"
  puts "-" * 60

  # FreeableMemory is reported in bytes
  memory_data = get_metric_statistics(options, "FreeableMemory", "Average", days)
  stats = calculate_stats(memory_data, "Average")

  if stats
    # Get instance specs to calculate total memory
    # t3.medium has 4 GB = 4,294,967,296 bytes
    instance_specs = {
      'db.t3.micro'   => 1 * 1024 * 1024 * 1024,
      'db.t3.small'   => 2 * 1024 * 1024 * 1024,
      'db.t3.medium'  => 4 * 1024 * 1024 * 1024,
      'db.t3.large'   => 8 * 1024 * 1024 * 1024,
      'db.t3.xlarge'  => 16 * 1024 * 1024 * 1024,
      'db.t3.2xlarge' => 32 * 1024 * 1024 * 1024,
      'db.r6g.large'  => 16 * 1024 * 1024 * 1024,
      'db.r6g.xlarge' => 32 * 1024 * 1024 * 1024
    }

    total_memory = instance_specs[CURRENT_INSTANCE_CLASS] || (4 * 1024 * 1024 * 1024)

    used_avg = ((total_memory - stats[:avg]) / total_memory.to_f) * 100
    used_max = ((total_memory - stats[:min]) / total_memory.to_f) * 100

    puts "  Total Memory:     #{format_bytes(total_memory)}"
    puts "  Average Free:     #{format_bytes(stats[:avg])} (#{format_percent(100 - used_avg)} used)"
    puts "  Min Free:         #{format_bytes(stats[:min])} (#{format_percent(used_max)} used at peak)"
    puts "  Max Free:         #{format_bytes(stats[:max])}"
    puts

    if used_max > 85
      puts "  ⚠️  Memory usage is very high (#{format_percent(used_max)} at peak)"
      puts "      Consider upgrading to instance with more memory"
    elsif used_avg < 40
      puts "  ℹ️  Memory utilization is low (#{format_percent(used_avg)} average)"
      puts "      May be over-provisioned, but MySQL benefits from buffer cache"
    else
      puts "  ✓ Memory utilization is healthy"
    end
  else
    puts "  Error: Could not retrieve memory metrics"
  end

  puts
  stats
end

def analyze_storage(options, days)
  puts "Storage Utilization"
  puts "-" * 60

  free_storage = get_metric_statistics(options, "FreeStorageSpace", "Average", days)
  stats = calculate_stats(free_storage, "Average")

  if stats
    total_storage = CURRENT_STORAGE_GB * 1024 * 1024 * 1024
    used_avg = ((total_storage - stats[:avg]) / total_storage.to_f) * 100
    used_max = ((total_storage - stats[:min]) / total_storage.to_f) * 100

    puts "  Total Storage:    #{CURRENT_STORAGE_GB} GB"
    puts "  Average Free:     #{format_bytes(stats[:avg])} (#{format_percent(used_avg)} used)"
    puts "  Min Free:         #{format_bytes(stats[:min])} (#{format_percent(used_max)} used)"
    puts

    if used_max > 85
      puts "  ⚠️  Storage is nearly full (#{format_percent(used_max)} used)"
      puts "      Consider increasing storage size"
    elsif used_avg < 50
      puts "  ℹ️  Storage is underutilized (#{format_percent(used_avg)} used)"
      puts "      Current allocation seems appropriate for growth"
    else
      puts "  ✓ Storage utilization is healthy"
    end
  else
    puts "  Error: Could not retrieve storage metrics"
  end

  puts
end

def analyze_iops(options, days)
  puts "IOPS Utilization"
  puts "-" * 60

  read_iops = get_metric_statistics(options, "ReadIOPS", "Average", days)
  write_iops = get_metric_statistics(options, "WriteIOPS", "Average", days)

  read_stats = calculate_stats(read_iops, "Average")
  write_stats = calculate_stats(write_iops, "Average")

  if read_stats && write_stats
    total_avg = read_stats[:avg] + write_stats[:avg]
    total_max = read_stats[:max] + write_stats[:max]
    total_p95 = read_stats[:p95] + write_stats[:p95]

    puts "  Provisioned IOPS: #{CURRENT_IOPS}"
    puts
    puts "  Read IOPS:"
    puts "    Average: #{read_stats[:avg].round(0)}"
    puts "    Max:     #{read_stats[:max].round(0)}"
    puts "    P95:     #{read_stats[:p95].round(0)}"
    puts
    puts "  Write IOPS:"
    puts "    Average: #{write_stats[:avg].round(0)}"
    puts "    Max:     #{write_stats[:max].round(0)}"
    puts "    P95:     #{write_stats[:p95].round(0)}"
    puts
    puts "  Total IOPS:"
    puts "    Average: #{total_avg.round(0)} (#{format_percent(total_avg / CURRENT_IOPS * 100)} of provisioned)"
    puts "    Max:     #{total_max.round(0)} (#{format_percent(total_max / CURRENT_IOPS * 100)} of provisioned)"
    puts "    P95:     #{total_p95.round(0)} (#{format_percent(total_p95 / CURRENT_IOPS * 100)} of provisioned)"
    puts

    utilization = (total_p95 / CURRENT_IOPS * 100)

    if utilization > 80
      puts "  ⚠️  IOPS utilization is high (#{format_percent(utilization)} at P95)"
      puts "      Consider increasing provisioned IOPS"
    elsif utilization < 30
      puts "  💰 IOPS significantly underutilized (#{format_percent(utilization)} at P95)"
      puts "      Consider reducing provisioned IOPS to save costs"

      # Calculate savings
      recommended_iops = [(total_p95 * 1.5).round(-2), 3000].max  # Round to nearest 100, min 3000 (gp3 baseline)
      if recommended_iops < CURRENT_IOPS
        monthly_savings = (CURRENT_IOPS - recommended_iops) * STORAGE_PRICING[:gp3][:iops_per_unit]
        puts "      Recommended: #{recommended_iops} IOPS (saves ~$#{monthly_savings.round(2)}/month)"
      end
    else
      puts "  ✓ IOPS utilization is appropriate"
    end
  else
    puts "  Error: Could not retrieve IOPS metrics"
  end

  puts
end

def analyze_connections(options, days)
  puts "Database Connections"
  puts "-" * 60

  connections = get_metric_statistics(options, "DatabaseConnections", "Average", days)
  stats = calculate_stats(connections, "Average")

  if stats
    # t3.medium default max_connections is typically ~150-200 depending on memory
    max_connections = 150

    puts "  Average Connections: #{stats[:avg].round(0)}"
    puts "  Max Connections:     #{stats[:max].round(0)}"
    puts "  P95 Connections:     #{stats[:p95].round(0)}"
    puts "  (Estimated max_connections: ~#{max_connections})"
    puts

    if stats[:max] > max_connections * 0.8
      puts "  ⚠️  Connection count approaching limit (#{stats[:max].round(0)}/~#{max_connections})"
      puts "      Monitor for connection exhaustion"
    elsif stats[:avg] < 20
      puts "  ✓ Connection count is healthy"
    else
      puts "  ✓ Connection utilization is normal"
    end
  else
    puts "  Error: Could not retrieve connection metrics"
  end

  puts
end

def analyze_network(options, days)
  puts "Network Throughput"
  puts "-" * 60

  rx_bytes = get_metric_statistics(options, "NetworkReceiveThroughput", "Average", days)
  tx_bytes = get_metric_statistics(options, "NetworkTransmitThroughput", "Average", days)

  rx_stats = calculate_stats(rx_bytes, "Average")
  tx_stats = calculate_stats(tx_bytes, "Average")

  if rx_stats && tx_stats
    puts "  Network Receive:"
    puts "    Average: #{format_bytes(rx_stats[:avg])}/sec"
    puts "    Max:     #{format_bytes(rx_stats[:max])}/sec"
    puts
    puts "  Network Transmit:"
    puts "    Average: #{format_bytes(tx_stats[:avg])}/sec"
    puts "    Max:     #{format_bytes(tx_stats[:max])}/sec"
    puts
    puts "  ✓ Network metrics for reference"
  else
    puts "  Error: Could not retrieve network metrics"
  end

  puts
end

def cost_analysis
  puts "Cost Analysis & Recommendations"
  puts "=" * 60
  puts

  current_monthly = INSTANCE_PRICING[CURRENT_INSTANCE_CLASS][:on_demand] * 730
  current_reserved = INSTANCE_PRICING[CURRENT_INSTANCE_CLASS][:reserved_1yr] * 730
  storage_monthly = CURRENT_STORAGE_GB * STORAGE_PRICING[:gp3][:storage_per_gb]
  iops_monthly = CURRENT_IOPS * STORAGE_PRICING[:gp3][:iops_per_unit]

  puts "Current Configuration:"
  puts "  Instance Class: #{CURRENT_INSTANCE_CLASS}"
  puts "  Storage:        #{CURRENT_STORAGE_GB} GB #{CURRENT_STORAGE_TYPE}"
  puts "  Provisioned IOPS: #{CURRENT_IOPS}"
  puts

  puts "Current Monthly Costs (On-Demand):"
  puts "  Instance:       $#{current_monthly.round(2)}"
  puts "  Storage:        $#{storage_monthly.round(2)}"
  puts "  Provisioned IOPS: $#{iops_monthly.round(2)}"
  puts "  Total:          $#{(current_monthly + storage_monthly + iops_monthly).round(2)}"
  puts

  puts "Savings with 1-Year Reserved Instance:"
  puts "  Instance:       $#{current_reserved.round(2)}/month"
  puts "  Monthly Savings: $#{(current_monthly - current_reserved).round(2)}"
  puts "  Annual Savings:  $#{((current_monthly - current_reserved) * 12).round(2)}"
  puts

  # Alternative instance sizes
  puts "Alternative Instance Classes (On-Demand):"
  ['db.t3.small', 'db.t3.medium', 'db.t3.large'].each do |instance_class|
    next unless INSTANCE_PRICING[instance_class]

    monthly = INSTANCE_PRICING[instance_class][:on_demand] * 730
    total = monthly + storage_monthly + iops_monthly
    savings = current_monthly - monthly

    marker = instance_class == CURRENT_INSTANCE_CLASS ? " (current)" : ""
    savings_text = savings != 0 ? " (#{savings > 0 ? 'saves' : 'costs'} $#{savings.abs.round(2)}/mo)" : ""

    puts "  #{instance_class}#{marker}: $#{total.round(2)}/month#{savings_text}"
  end
  puts
end

# Main execution
puts "RDS Sizing Analysis Tool"
puts "=" * 60
puts "Database Instance: #{DB_INSTANCE}"
puts "Region: #{REGION}"
puts "Analysis Period: Last #{options[:days]} days"
puts "=" * 60
puts

analyze_cpu(options, options[:days])
analyze_memory(options, options[:days])
analyze_storage(options, options[:days])
analyze_iops(options, options[:days])
analyze_connections(options, options[:days])
analyze_network(options, options[:days])

cost_analysis

puts
puts "Summary Recommendations:"
puts "=" * 60
puts "1. Review CPU/memory utilization to determine optimal instance size"
puts "2. Consider Reserved Instance for ~35% savings on compute"
puts "3. Check IOPS utilization - reduce provisioned IOPS if underutilized"
puts "4. Monitor storage growth and plan for expansion if needed"
puts "5. Verify connection patterns align with application needs"
puts
puts "For detailed metrics, view in CloudWatch:"
puts "  https://console.aws.amazon.com/cloudwatch/home?region=#{REGION}#dashboards:name=RDS"
