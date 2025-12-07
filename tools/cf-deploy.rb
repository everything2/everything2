#!/usr/bin/env ruby
# frozen_string_literal: true

# CloudFormation Deployment Tool for Everything2
#
# Usage:
#   ./tools/cf-deploy.rb production          # Deploy main stack to us-west-2
#   ./tools/cf-deploy.rb cloudfront          # Deploy CloudFront stack to us-east-1
#   ./tools/cf-deploy.rb status              # Check status of both stacks
#   ./tools/cf-deploy.rb outputs             # Show stack outputs
#   ./tools/cf-deploy.rb validate            # Validate templates
#   ./tools/cf-deploy.rb diff production     # Show changeset preview
#
# Environment:
#   AWS_PROFILE - AWS profile to use (optional)

require 'json'
require 'open3'
require 'time'

class CFDeploy
  STACKS = {
    'production' => {
      name: 'everything2-production',
      template: 'cf/everything2-production.json',
      region: 'us-west-2',
      capabilities: ['CAPABILITY_NAMED_IAM']
    },
    'cloudfront' => {
      name: 'everything2-cloudfront',
      template: 'cf/everything2-cloudfront.json',
      region: 'us-east-1',
      capabilities: [],
      parameters: [
        # ALBDomainName will be prompted or fetched from production stack
      ]
    }
  }.freeze

  def initialize
    @project_root = File.expand_path('..', __dir__)
  end

  def run(args)
    command = args[0]
    target = args[1]

    case command
    when 'production'
      deploy('production')
    when 'cloudfront'
      deploy('cloudfront')
    when 'status'
      status
    when 'outputs'
      outputs(target)
    when 'validate'
      validate(target)
    when 'diff'
      diff(target || 'production')
    when 'cache-stats'
      cache_stats
    when 'ecs-status'
      ecs_status
    when 'help', '-h', '--help', nil
      help
    else
      puts "Unknown command: #{command}"
      help
      exit 1
    end
  end

  private

  S3_TEMPLATE_BUCKET = 'cloudformation.everything2.com'
  S3_TEMPLATE_PREFIX = 'templates'

  def deploy(stack_key)
    config = STACKS[stack_key]
    unless config
      puts "Unknown stack: #{stack_key}"
      exit 1
    end

    template_path = File.join(@project_root, config[:template])
    unless File.exist?(template_path)
      puts "Template not found: #{template_path}"
      exit 1
    end

    puts "Deploying #{config[:name]} to #{config[:region]}..."

    # Check if stack exists
    exists = stack_exists?(config[:name], config[:region])

    # Build parameters
    params = build_parameters(stack_key, config)

    # Check template size - use S3 for large templates
    template_size = File.size(template_path)
    use_s3 = template_size > 51200

    if use_s3
      s3_key = "#{S3_TEMPLATE_PREFIX}/#{File.basename(config[:template])}"
      s3_url = "https://#{S3_TEMPLATE_BUCKET}.s3.amazonaws.com/#{s3_key}"

      puts "Template too large for inline (#{template_size} bytes), uploading to S3..."
      upload_cmd = [
        'aws', 's3', 'cp', template_path,
        "s3://#{S3_TEMPLATE_BUCKET}/#{s3_key}",
        '--region', 'us-west-2'
      ]
      unless system(*upload_cmd)
        puts "Failed to upload template to S3"
        exit 1
      end
      puts "Uploaded to: #{s3_url}"
    end

    # Build command
    cmd = [
      'aws', 'cloudformation',
      exists ? 'update-stack' : 'create-stack',
      '--stack-name', config[:name],
      '--region', config[:region]
    ]

    if use_s3
      cmd += ['--template-url', s3_url]
    else
      cmd += ['--template-body', "file://#{template_path}"]
    end

    if config[:capabilities].any?
      cmd += ['--capabilities', *config[:capabilities]]
    end

    if params.any?
      param_strings = params.map { |k, v| "ParameterKey=#{k},ParameterValue=#{v}" }
      cmd += ['--parameters', *param_strings]
    end

    puts "Running: #{cmd.join(' ')}"
    puts

    success = system(*cmd)

    if success
      puts
      puts "Stack #{exists ? 'update' : 'create'} initiated."
      puts "Monitor progress with: ./tools/cf-deploy.rb status"
      wait_for_stack(config[:name], config[:region])
    else
      puts "Deployment failed!"
      exit 1
    end
  end

  def build_parameters(stack_key, config)
    params = {}

    if stack_key == 'cloudfront'
      # Fetch ALB domain name from production stack
      alb_domain = get_alb_domain
      if alb_domain
        params['ALBDomainName'] = alb_domain
        puts "Using ALB: #{alb_domain}"
      else
        print "Enter ALB domain name (e.g., E2-Containerized-Frontend-ELB-xxx.us-west-2.elb.amazonaws.com): "
        params['ALBDomainName'] = $stdin.gets.chomp
      end
    elsif stack_key == 'production'
      # Fetch CloudFront domain name if cloudfront stack exists
      cf_domain = get_cloudfront_domain
      if cf_domain
        params['CloudFrontDomainName'] = cf_domain
        puts "Using CloudFront: #{cf_domain}"
      else
        puts "CloudFront not deployed - Route53 will point to ALB directly"
      end
    end

    params
  end

  def get_alb_domain
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', 'everything2-production',
      '--region', 'us-west-2',
      '--query', 'Stacks[0].Outputs[?OutputKey==`ELBDNSName`].OutputValue',
      '--output', 'text'
    ]

    stdout, status = Open3.capture2(*cmd)
    return nil unless status.success?

    domain = stdout.strip
    domain.empty? ? nil : domain
  rescue
    nil
  end

  def get_cloudfront_domain
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', 'everything2-cloudfront',
      '--region', 'us-east-1',
      '--query', 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomainName`].OutputValue',
      '--output', 'text'
    ]

    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?

    domain = stdout.strip
    domain.empty? ? nil : domain
  rescue
    nil
  end

  def stack_exists?(stack_name, region)
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', stack_name,
      '--region', region
    ]
    _, status = Open3.capture2(*cmd, err: '/dev/null')
    status.success?
  end

  def wait_for_stack(stack_name, region)
    puts
    puts "Waiting for stack operation to complete..."

    cmd = [
      'aws', 'cloudformation', 'wait', 'stack-update-complete',
      '--stack-name', stack_name,
      '--region', region
    ]

    # Try update-complete first, then create-complete
    system(*cmd) || system(*cmd.map { |c| c == 'stack-update-complete' ? 'stack-create-complete' : c })

    puts "Stack operation complete!"
    show_outputs(stack_name, region)
  end

  def status
    puts "Stack Status"
    puts "=" * 60

    STACKS.each do |key, config|
      puts
      puts "#{key.upcase} (#{config[:region]})"
      puts "-" * 40

      cmd = [
        'aws', 'cloudformation', 'describe-stacks',
        '--stack-name', config[:name],
        '--region', config[:region],
        '--query', 'Stacks[0].{Status:StackStatus,Updated:LastUpdatedTime}',
        '--output', 'table'
      ]

      stdout, status = Open3.capture2(*cmd, err: '/dev/null')
      if status.success?
        puts stdout
      else
        puts "  Stack does not exist"
      end
    end
  end

  def outputs(target)
    stacks = target ? [target] : STACKS.keys

    stacks.each do |key|
      config = STACKS[key]
      next unless config

      puts "#{key.upcase} Outputs (#{config[:region]})"
      puts "-" * 60
      show_outputs(config[:name], config[:region])
      puts
    end
  end

  def cache_stats
    # Get CloudFront distribution ID
    dist_id = get_cloudfront_distribution_id
    unless dist_id
      puts "CloudFront distribution not found. Deploy cloudfront stack first."
      exit 1
    end

    puts "CloudFront Cache Statistics"
    puts "Distribution: #{dist_id}"
    puts "=" * 60

    # Time range - last 24 hours
    end_time = Time.now.utc
    start_time = end_time - (24 * 60 * 60)

    metrics = [
      { name: 'CacheHitRate', label: 'Cache Hit Rate', unit: '%', stat: 'Average' },
      { name: 'Requests', label: 'Total Requests', unit: '', stat: 'Sum' },
      { name: 'BytesDownloaded', label: 'Bytes Downloaded', unit: 'bytes', stat: 'Sum' },
      { name: 'OriginLatency', label: 'Origin Latency', unit: 'ms', stat: 'Average' }
    ]

    puts
    puts "Last 24 hours:"
    puts "-" * 40

    metrics.each do |metric|
      value = get_cloudfront_metric(dist_id, metric[:name], start_time, end_time, metric[:stat])
      if value
        formatted = format_metric_value(value, metric[:unit])
        puts "  #{metric[:label].ljust(20)} #{formatted}"
      else
        puts "  #{metric[:label].ljust(20)} N/A"
      end
    end

    # Get hourly breakdown for cache hit rate
    puts
    puts "Cache Hit Rate (last 6 hours, hourly):"
    puts "-" * 40

    6.downto(1) do |hours_ago|
      period_end = Time.now.utc - ((hours_ago - 1) * 3600)
      period_start = period_end - 3600
      value = get_cloudfront_metric(dist_id, 'CacheHitRate', period_start, period_end, 'Average')
      time_label = period_start.strftime('%H:%M')
      if value
        bar = '█' * (value / 5).to_i
        puts "  #{time_label} UTC  #{format('%.1f', value)}% #{bar}"
      else
        puts "  #{time_label} UTC  N/A"
      end
    end
  end

  def ecs_status
    puts "ECS Service Health"
    puts "=" * 60

    # Find ECS cluster and service (E2 naming convention)
    cluster, service = find_ecs_service

    unless cluster && service
      puts "Could not find ECS cluster/service. Is production stack deployed?"
      exit 1
    end

    puts "Cluster: #{cluster}"
    puts "Service: #{service}"
    puts

    # Get service details
    cmd = [
      'aws', 'ecs', 'describe-services',
      '--cluster', cluster,
      '--services', service,
      '--region', 'us-west-2',
      '--output', 'json'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    unless status.success?
      puts "Failed to get service details"
      exit 1
    end

    data = JSON.parse(stdout)
    svc = data['services']&.first
    unless svc
      puts "Service not found"
      exit 1
    end

    # Service status
    puts "Service Status"
    puts "-" * 40
    puts "  Status:          #{svc['status']}"
    puts "  Running Tasks:   #{svc['runningCount']}"
    puts "  Desired Tasks:   #{svc['desiredCount']}"
    puts "  Pending Tasks:   #{svc['pendingCount']}"

    # Health check
    healthy = svc['runningCount'] == svc['desiredCount'] && svc['runningCount'] > 0
    health_status = healthy ? '✓ HEALTHY' : '✗ UNHEALTHY'
    puts "  Health:          #{health_status}"
    puts

    # Recent deployments
    deployments = svc['deployments'] || []
    if deployments.any?
      puts "Deployments"
      puts "-" * 40
      deployments.each do |dep|
        status_icon = dep['status'] == 'PRIMARY' ? '●' : '○'
        created = Time.parse(dep['createdAt']).strftime('%Y-%m-%d %H:%M UTC')
        puts "  #{status_icon} #{dep['status'].ljust(10)} #{dep['runningCount']}/#{dep['desiredCount']} tasks  #{created}"
        puts "    Task def: #{dep['taskDefinition'].split('/').last}"
        if dep['rolloutState']
          puts "    Rollout:  #{dep['rolloutState']}"
        end
      end
      puts
    end

    # Recent events (last 5)
    events = (svc['events'] || []).first(5)
    if events.any?
      puts "Recent Events"
      puts "-" * 40
      events.each do |event|
        time = Time.parse(event['createdAt']).strftime('%H:%M')
        msg = event['message'].gsub(/\(service #{service}\)\s*/, '')
        # Truncate long messages
        msg = msg[0..75] + '...' if msg.length > 78
        puts "  #{time}  #{msg}"
      end
      puts
    end

    # CPU/Memory utilization from CloudWatch
    puts "Resource Utilization (last hour avg)"
    puts "-" * 40
    end_time = Time.now.utc
    start_time = end_time - 3600

    cpu = get_ecs_metric(cluster, service, 'CPUUtilization', start_time, end_time)
    mem = get_ecs_metric(cluster, service, 'MemoryUtilization', start_time, end_time)

    cpu_str = cpu ? format('%.1f%%', cpu) : 'N/A'
    mem_str = mem ? format('%.1f%%', mem) : 'N/A'
    puts "  CPU:             #{cpu_str}"
    puts "  Memory:          #{mem_str}"
  end

  def find_ecs_service
    # List clusters and find E2 cluster
    cmd = ['aws', 'ecs', 'list-clusters', '--region', 'us-west-2', '--output', 'json']
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?

    clusters = JSON.parse(stdout)['clusterArns'] || []
    cluster_arn = clusters.find { |c| c.include?('E2-App') || c.include?('everything2') }
    return nil unless cluster_arn

    cluster = cluster_arn.split('/').last

    # List services in cluster
    cmd = ['aws', 'ecs', 'list-services', '--cluster', cluster, '--region', 'us-west-2', '--output', 'json']
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?

    services = JSON.parse(stdout)['serviceArns'] || []
    service_arn = services.find { |s| s.include?('E2-App') || s.include?('everything2') }
    return nil unless service_arn

    service = service_arn.split('/').last

    [cluster, service]
  rescue
    nil
  end

  def get_stack_output(stack_name, region, output_key)
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', stack_name,
      '--region', region,
      '--query', "Stacks[0].Outputs[?OutputKey==`#{output_key}`].OutputValue",
      '--output', 'text'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?
    value = stdout.strip
    value.empty? ? nil : value
  rescue
    nil
  end

  def get_ecs_metric(cluster, service, metric_name, start_time, end_time)
    cmd = [
      'aws', 'cloudwatch', 'get-metric-statistics',
      '--namespace', 'AWS/ECS',
      '--metric-name', metric_name,
      '--dimensions', "Name=ClusterName,Value=#{cluster}", "Name=ServiceName,Value=#{service}",
      '--start-time', start_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
      '--end-time', end_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
      '--period', '3600',
      '--statistics', 'Average',
      '--region', 'us-west-2',
      '--output', 'json'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?

    data = JSON.parse(stdout)
    datapoints = data['Datapoints']
    return nil if datapoints.empty?

    latest = datapoints.max_by { |dp| dp['Timestamp'] }
    latest['Average']
  rescue
    nil
  end

  def get_cloudfront_distribution_id
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', 'everything2-cloudfront',
      '--region', 'us-east-1',
      '--query', 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue',
      '--output', 'text'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?
    dist_id = stdout.strip
    dist_id.empty? ? nil : dist_id
  end

  def get_cloudfront_metric(dist_id, metric_name, start_time, end_time, statistic)
    cmd = [
      'aws', 'cloudwatch', 'get-metric-statistics',
      '--namespace', 'AWS/CloudFront',
      '--metric-name', metric_name,
      '--dimensions', "Name=DistributionId,Value=#{dist_id}", 'Name=Region,Value=Global',
      '--start-time', start_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
      '--end-time', end_time.strftime('%Y-%m-%dT%H:%M:%SZ'),
      '--period', '3600',
      '--statistics', statistic,
      '--region', 'us-east-1',
      '--output', 'json'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?

    data = JSON.parse(stdout)
    datapoints = data['Datapoints']
    return nil if datapoints.empty?

    # Get most recent datapoint
    latest = datapoints.max_by { |dp| dp['Timestamp'] }
    latest[statistic]
  rescue
    nil
  end

  def format_metric_value(value, unit)
    case unit
    when '%'
      format('%.2f%%', value)
    when 'bytes'
      if value > 1_000_000_000
        format('%.2f GB', value / 1_000_000_000.0)
      elsif value > 1_000_000
        format('%.2f MB', value / 1_000_000.0)
      elsif value > 1_000
        format('%.2f KB', value / 1_000.0)
      else
        "#{value.to_i} bytes"
      end
    when 'ms'
      format('%.0f ms', value)
    else
      value.to_s
    end
  end

  def show_outputs(stack_name, region)
    cmd = [
      'aws', 'cloudformation', 'describe-stacks',
      '--stack-name', stack_name,
      '--region', region,
      '--query', 'Stacks[0].Outputs',
      '--output', 'table'
    ]

    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    if status.success?
      puts stdout
    else
      puts "  No outputs (stack may not exist)"
    end
  end

  def validate(target)
    templates = target ? [STACKS[target]].compact : STACKS.values

    if templates.empty?
      puts "Unknown stack: #{target}"
      exit 1
    end

    all_valid = true

    templates.each do |config|
      template_path = File.join(@project_root, config[:template])
      puts "Validating #{config[:template]}..."

      # JSON syntax check
      begin
        content = File.read(template_path)
        JSON.parse(content)
        puts "  ✓ Valid JSON"
      rescue JSON::ParserError => e
        puts "  ✗ Invalid JSON: #{e.message}"
        all_valid = false
        next
      end

      # CloudFormation validation - use S3 for large templates
      if content.length > 51200
        puts "  ⚠ Template too large for inline validation (#{content.length} bytes)"
        puts "  ℹ Upload to S3 and use --template-url for full validation"
        puts "  ✓ JSON structure valid (CloudFormation validation skipped)"
      else
        cmd = [
          'aws', 'cloudformation', 'validate-template',
          '--template-body', "file://#{template_path}",
          '--region', config[:region]
        ]

        _, status = Open3.capture2(*cmd, err: $stderr)
        if status.success?
          puts "  ✓ Valid CloudFormation template"
        else
          puts "  ✗ CloudFormation validation failed"
          all_valid = false
        end
      end
    end

    exit(all_valid ? 0 : 1)
  end

  def diff(stack_key)
    config = STACKS[stack_key]
    unless config
      puts "Unknown stack: #{stack_key}"
      exit 1
    end

    template_path = File.join(@project_root, config[:template])
    changeset_name = "preview-#{Time.now.to_i}"

    puts "Creating changeset preview for #{config[:name]}..."

    # Build parameters
    params = build_parameters(stack_key, config)

    # Create changeset
    cmd = [
      'aws', 'cloudformation', 'create-change-set',
      '--stack-name', config[:name],
      '--template-body', "file://#{template_path}",
      '--change-set-name', changeset_name,
      '--region', config[:region]
    ]

    if config[:capabilities].any?
      cmd += ['--capabilities', *config[:capabilities]]
    end

    if params.any?
      param_strings = params.map { |k, v| "ParameterKey=#{k},ParameterValue=#{v}" }
      cmd += ['--parameters', *param_strings]
    end

    _, status = Open3.capture2(*cmd)
    unless status.success?
      puts "Failed to create changeset"
      exit 1
    end

    # Wait for changeset
    puts "Waiting for changeset..."
    wait_cmd = [
      'aws', 'cloudformation', 'wait', 'change-set-create-complete',
      '--stack-name', config[:name],
      '--change-set-name', changeset_name,
      '--region', config[:region]
    ]
    system(*wait_cmd)

    # Describe changeset
    describe_cmd = [
      'aws', 'cloudformation', 'describe-change-set',
      '--stack-name', config[:name],
      '--change-set-name', changeset_name,
      '--region', config[:region],
      '--query', 'Changes[].{Action:ResourceChange.Action,Resource:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType}',
      '--output', 'table'
    ]

    puts
    puts "Proposed changes:"
    system(*describe_cmd)

    # Clean up changeset
    cleanup_cmd = [
      'aws', 'cloudformation', 'delete-change-set',
      '--stack-name', config[:name],
      '--change-set-name', changeset_name,
      '--region', config[:region]
    ]
    system(*cleanup_cmd, out: '/dev/null', err: '/dev/null')
  end

  def help
    puts <<~HELP
      CloudFormation Deployment Tool for Everything2

      Usage:
        ./tools/cf-deploy.rb <command> [stack]

      Commands:
        production     Deploy main stack to us-west-2
        cloudfront     Deploy CloudFront stack to us-east-1
        status         Show status of all stacks
        outputs [stack] Show stack outputs
        validate [stack] Validate templates
        diff <stack>   Preview changes (create changeset)
        cache-stats    Show CloudFront cache hit rate and metrics
        ecs-status     Show ECS service health and resource utilization
        help           Show this help

      Stacks:
        production     Main E2 infrastructure (us-west-2)
                       - VPC, ECS, RDS, ALB, WAF, S3, etc.

        cloudfront     CloudFront CDN (us-east-1)
                       - CloudFront distribution
                       - WAF (CLOUDFRONT scope)
                       - ACM certificate
                       - Cache policies

      Examples:
        ./tools/cf-deploy.rb validate             # Validate all templates
        ./tools/cf-deploy.rb diff production      # Preview production changes
        ./tools/cf-deploy.rb production           # Deploy production stack
        ./tools/cf-deploy.rb cloudfront           # Deploy CloudFront stack
        ./tools/cf-deploy.rb outputs cloudfront   # Show CloudFront outputs
        ./tools/cf-deploy.rb cache-stats          # Show cache hit rate
        ./tools/cf-deploy.rb ecs-status           # Show ECS health

      Notes:
        - CloudFront stack requires production stack to be deployed first
        - ALB domain name is auto-fetched from production stack outputs
        - After deploying CloudFront, update Route53 to point to CF distribution
    HELP
  end
end

CFDeploy.new.run(ARGV)
