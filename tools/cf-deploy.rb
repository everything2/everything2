#!/usr/bin/env ruby
# frozen_string_literal: true

# CloudFormation Deployment Tool for Everything2
#
# Usage:
#   ./tools/cf-deploy.rb production          # Preview, confirm, then update the main stack (us-west-2)
#   ./tools/cf-deploy.rb cloudfront          # Deploy CloudFront stack to us-east-1
#   ./tools/cf-deploy.rb status              # Check status of both stacks
#   ./tools/cf-deploy.rb outputs             # Show stack outputs
#   ./tools/cf-deploy.rb validate            # Validate templates
#   ./tools/cf-deploy.rb diff production     # Show changeset preview
#   ./tools/cf-deploy.rb drift production    # Compare live resources with the template
#   ./tools/cf-deploy.rb protect production  # Turn on stack termination protection
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
      capabilities: ['CAPABILITY_NAMED_IAM'],
      # Denies replacing or deleting the database. Applied on every deploy so a recreated
      # stack is never left without it.
      stack_policy: 'cf/stack-policy.json',
      tags: { 'app' => 'e2' }
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
    when 'drift'
      drift(target || 'production')
    when 'protect'
      termination_protection(target || 'production', true)
    when 'unprotect'
      termination_protection(target || 'production', false)
    when 'cache-stats'
      cache_stats
    when 'ecs-status'
      ecs_status
    when 'invalidate'
      invalidate_cache(target)
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

  # A change set that definitely replaces or removes one of these is refused outright. CloudFormation
  # marks most RDS instance properties "Conditional" (some instance setups need recreating for
  # them); for our standalone instance those have always applied in place (engine upgrades
  # included), so a Conditional change needs the stack name typed, and the stack policy denies an
  # actual replacement at execution.
  NEVER_REPLACE = ['AWS::RDS::DBInstance'].freeze

  def deploy(stack_key)
    config = stack_config(stack_key)
    puts "Deploying #{config[:name]} to #{config[:region]}..."

    params = build_parameters(stack_key, config)
    template = template_args(config)

    unless stack_exists?(config[:name], config[:region])
      create_stack(config, template, params)
      return
    end

    changeset = create_change_set(config, template, params, 'deploy')
    if changeset == :no_changes
      puts "No changes: #{config[:name]} already matches the template."
      apply_stack_policy(config)
      return
    end

    changes = changeset['Changes'] || []
    print_changes(changes)

    refused = refused_changes(changes)
    if refused.any?
      puts
      puts "REFUSED: this change set would replace or delete:"
      refused.each { |c| puts "  #{c['LogicalResourceId']} (#{c['ResourceType']})" }
      puts "Nothing was changed. Fix the template; a database is never replaced through this tool."
      delete_change_set(config, changeset['ChangeSetName'])
      exit 1
    end

    risky = risky_changes(changes)
    puts
    if risky.any?
      puts "WARNING: #{risky.size} resource(s) may be replaced or removed (marked !! above)."
      risky.select { |c| NEVER_REPLACE.include?(c['ResourceType']) }.each do |c|
        puts "  #{c['LogicalResourceId']}: CloudFormation can't rule out replacing it. The stack policy denies an"
        puts "  actual replacement, which would fail the update and roll it back."
      end
      answer = ask("Type the stack name (#{config[:name]}) to execute this change set: ")
      confirmed = answer == config[:name]
    else
      answer = ask("Execute this change set on #{config[:name]}? Type 'yes': ")
      confirmed = answer == 'yes'
    end

    unless confirmed
      puts "Not executed. The change set has been deleted; nothing was changed."
      delete_change_set(config, changeset['ChangeSetName'])
      exit 1
    end

    apply_stack_policy(config)
    execute_change_set(config, changeset['ChangeSetName'])
  end

  def stack_config(stack_key)
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
    config
  end

  # --template-body for small templates; larger ones (over CloudFormation's 51,200-byte
  # inline limit) are uploaded to S3 and passed as --template-url.
  def template_args(config)
    template_path = File.join(@project_root, config[:template])
    template_size = File.size(template_path)
    return ['--template-body', "file://#{template_path}"] if template_size <= 51200

    s3_key = "#{S3_TEMPLATE_PREFIX}/#{File.basename(config[:template])}"
    s3_url = "https://#{S3_TEMPLATE_BUCKET}.s3.amazonaws.com/#{s3_key}"
    puts "Template too large for inline (#{template_size} bytes), uploading to S3..."
    upload_cmd = ['aws', 's3', 'cp', template_path, "s3://#{S3_TEMPLATE_BUCKET}/#{s3_key}", '--region', 'us-west-2']
    unless system(*upload_cmd, out: File::NULL)
      puts "Failed to upload template to S3"
      exit 1
    end
    puts "Uploaded to: #{s3_url}"
    ['--template-url', s3_url]
  end

  def stack_args(config, params)
    args = []
    args += ['--capabilities', *config[:capabilities]] if config[:capabilities].any?
    if params.any?
      args += ['--parameters', *params.map { |k, v| "ParameterKey=#{k},ParameterValue=#{v}" }]
    end
    if config[:tags]&.any?
      args += ['--tags', *config[:tags].map { |k, v| "Key=#{k},Value=#{v}" }]
    end
    args
  end

  def create_stack(config, template, params)
    cmd = ['aws', 'cloudformation', 'create-stack',
           '--stack-name', config[:name], '--region', config[:region]] +
          template + stack_args(config, params)
    if config[:stack_policy]
      # Born protected: the stack policy, and termination protection.
      cmd += ['--stack-policy-body', "file://#{File.join(@project_root, config[:stack_policy])}",
              '--enable-termination-protection']
    end
    puts "Creating #{config[:name]}..."
    unless system(*cmd)
      puts "Stack create failed!"
      exit 1
    end
    wait_for_stack(config[:name], config[:region], 'stack-create-complete')
  end

  # Creates a change set and waits for it. Returns its description (with every page of
  # Changes), or :no_changes when the template matches the stack.
  def create_change_set(config, template, params, purpose)
    name = "#{purpose}-#{Time.now.to_i}"
    cmd = ['aws', 'cloudformation', 'create-change-set',
           '--stack-name', config[:name], '--change-set-name', name,
           '--region', config[:region]] + template + stack_args(config, params)
    _, err, status = Open3.capture3(*cmd)
    unless status.success?
      puts "Failed to create change set: #{err.strip}"
      exit 1
    end

    puts "Waiting for change set #{name}..."
    wait_cmd = ['aws', 'cloudformation', 'wait', 'change-set-create-complete',
                '--stack-name', config[:name], '--change-set-name', name, '--region', config[:region]]
    system(*wait_cmd, err: File::NULL)

    changeset = describe_change_set(config, name)
    if changeset['Status'] == 'FAILED'
      reason = changeset['StatusReason'].to_s
      delete_change_set(config, name)
      return :no_changes if reason.include?("didn't contain changes") || reason.include?('No updates are to be performed')

      puts "Change set failed: #{reason}"
      exit 1
    end
    changeset
  end

  def describe_change_set(config, name)
    changes = []
    token = nil
    loop do
      cmd = ['aws', 'cloudformation', 'describe-change-set',
             '--stack-name', config[:name], '--change-set-name', name,
             '--region', config[:region], '--output', 'json']
      cmd += ['--next-token', token] if token
      out, err, status = Open3.capture3(*cmd)
      unless status.success?
        puts "Failed to describe change set: #{err.strip}"
        exit 1
      end
      page = JSON.parse(out)
      changes.concat((page['Changes'] || []).map { |c| c['ResourceChange'] }.compact)
      token = page['NextToken']
      return page.merge('Changes' => changes) unless token
    end
  end

  def delete_change_set(config, name)
    system('aws', 'cloudformation', 'delete-change-set',
           '--stack-name', config[:name], '--change-set-name', name, '--region', config[:region],
           out: File::NULL, err: File::NULL)
  end

  def execute_change_set(config, name)
    cmd = ['aws', 'cloudformation', 'execute-change-set',
           '--stack-name', config[:name], '--change-set-name', name, '--region', config[:region]]
    unless system(*cmd)
      puts "Failed to execute change set!"
      exit 1
    end
    puts "Change set #{name} executing."
    wait_for_stack(config[:name], config[:region], 'stack-update-complete')
  end

  # Applies the stack's policy file when the live policy differs from it.
  def apply_stack_policy(config)
    return unless config[:stack_policy]

    path = File.join(@project_root, config[:stack_policy])
    wanted = JSON.parse(File.read(path))
    out, status = Open3.capture2('aws', 'cloudformation', 'get-stack-policy',
                                 '--stack-name', config[:name], '--region', config[:region], '--output', 'json')
    live_body = status.success? ? JSON.parse(out)['StackPolicyBody'] : nil
    live = live_body ? JSON.parse(live_body) : nil
    return if live == wanted

    puts "Applying stack policy from #{config[:stack_policy]}..."
    ok = system('aws', 'cloudformation', 'set-stack-policy', '--stack-name', config[:name],
                '--region', config[:region], '--stack-policy-body', "file://#{path}")
    unless ok
      puts "Failed to apply the stack policy; not continuing."
      exit 1
    end
  end

  def replaces?(change)
    %w[True Conditional].include?(change['Replacement'].to_s)
  end

  def removes?(change)
    change['Action'] == 'Remove'
  end

  def refused_changes(changes)
    changes.select { |c| NEVER_REPLACE.include?(c['ResourceType']) && (c['Replacement'].to_s == 'True' || removes?(c)) }
  end

  def risky_changes(changes)
    changes.select { |c| replaces?(c) || removes?(c) }
  end

  def print_changes(changes)
    puts
    puts "Proposed changes (#{changes.size}):"
    puts '-' * 100
    puts format('   %-8s %-40s %-36s %s', 'Action', 'Resource', 'Type', 'Replacement')
    changes.each do |c|
      flag = replaces?(c) || removes?(c) ? '!!' : '  '
      replacement = c['Action'] == 'Modify' ? c['Replacement'].to_s : ''
      puts format('%s %-8s %-40s %-36s %s', flag, c['Action'], c['LogicalResourceId'], c['ResourceType'], replacement)
      details = c['Details'] || []
      direct, knock_on = details.partition { |d| d['ChangeSource'] == 'DirectModification' }
      props = direct.map do |d|
        name = d.dig('Target', 'Name') || d.dig('Target', 'Attribute')
        recreation = d.dig('Target', 'RequiresRecreation')
        name && recreation && recreation != 'Never' ? "#{name} (recreation: #{recreation})" : name
      end.compact.uniq
      puts "            changes: #{props.join(', ')}" if props.any?
      # Changes that only follow from another resource (a reference or attribute it uses).
      causes = knock_on.map { |d| d['CausingEntity'] || d['ChangeSource'] }.compact.uniq
      puts "            follows: #{causes.join(', ')}" if causes.any?
    end
    direct_count = changes.count { |c| (c['Details'] || []).any? { |d| d['ChangeSource'] == 'DirectModification' } }
    puts "#{direct_count} changed directly by the template; the rest follow from those." if direct_count < changes.size
    puts '-' * 100
  end

  def ask(prompt)
    print prompt
    $stdout.flush
    ($stdin.gets || '').strip
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
      # Route53 points directly to ALB (CloudFront disabled)
      # CloudFront stack is kept available for quick re-enablement if needed
      puts "Route53 will point to ALB directly (CloudFront bypass mode)"
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

  def wait_for_stack(stack_name, region, waiter)
    puts
    puts "Waiting for stack operation to complete..."
    ok = system('aws', 'cloudformation', 'wait', waiter, '--stack-name', stack_name, '--region', region)
    unless ok
      puts "Stack operation did not complete successfully. Most recent failures:"
      system('aws', 'cloudformation', 'describe-stack-events', '--stack-name', stack_name, '--region', region,
             '--max-items', '15', '--output', 'table',
             '--query', "StackEvents[?contains(ResourceStatus, 'FAILED')].[Timestamp,LogicalResourceId,ResourceStatusReason]")
      exit 1
    end

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

  def invalidate_cache(paths)
    dist_id = get_cloudfront_distribution_id
    unless dist_id
      # Try to find distribution by alias if stack output not available
      dist_id = find_distribution_by_alias('everything2.com')
    end

    unless dist_id
      puts "CloudFront distribution not found."
      exit 1
    end

    # Default to invalidate everything if no paths specified
    paths ||= '/*'

    # Handle multiple paths separated by spaces
    path_list = paths.split(/\s+/)

    puts "CloudFront Cache Invalidation"
    puts "=" * 60
    puts "Distribution: #{dist_id}"
    puts "Paths: #{path_list.join(', ')}"
    puts

    cmd = [
      'aws', 'cloudfront', 'create-invalidation',
      '--distribution-id', dist_id,
      '--paths', *path_list
    ]

    stdout, status = Open3.capture2(*cmd)
    unless status.success?
      puts "Failed to create invalidation"
      exit 1
    end

    data = JSON.parse(stdout)
    invalidation = data['Invalidation']

    puts "Invalidation created!"
    puts "  ID:     #{invalidation['Id']}"
    puts "  Status: #{invalidation['Status']}"
    puts "  Time:   #{invalidation['CreateTime']}"
    puts
    puts "Invalidation typically takes 1-5 minutes to complete globally."
    puts "Check status with: aws cloudfront get-invalidation --distribution-id #{dist_id} --id #{invalidation['Id']}"
  end

  def find_distribution_by_alias(alias_name)
    cmd = [
      'aws', 'cloudfront', 'list-distributions',
      '--query', "DistributionList.Items[?contains(Aliases.Items, `#{alias_name}`)].Id",
      '--output', 'text'
    ]
    stdout, status = Open3.capture2(*cmd, err: '/dev/null')
    return nil unless status.success?
    dist_id = stdout.strip
    dist_id.empty? ? nil : dist_id
  rescue
    nil
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

  # Shows what a deploy would change, then deletes the change set. Changes nothing.
  def diff(stack_key)
    config = stack_config(stack_key)
    puts "Creating change set preview for #{config[:name]}..."
    params = build_parameters(stack_key, config)
    changeset = create_change_set(config, template_args(config), params, 'preview')
    if changeset == :no_changes
      puts "No changes: #{config[:name]} already matches the template."
      return
    end

    changes = changeset['Changes'] || []
    print_changes(changes)
    refused = refused_changes(changes)
    puts "A deploy would REFUSE this: it replaces or deletes #{refused.map { |c| c['LogicalResourceId'] }.join(', ')}." if refused.any?
    delete_change_set(config, changeset['ChangeSetName'])
  end

  # Runs CloudFormation's drift detection on the whole stack and lists the resources whose live
  # configuration no longer matches the template. Changes nothing.
  def drift(stack_key)
    config = stack_config(stack_key)
    puts "Detecting drift on #{config[:name]}..."
    out, err, status = Open3.capture3('aws', 'cloudformation', 'detect-stack-drift',
                                      '--stack-name', config[:name], '--region', config[:region], '--output', 'json')
    unless status.success?
      puts "Failed to start drift detection: #{err.strip}"
      exit 1
    end
    detection_id = JSON.parse(out)['StackDriftDetectionId']

    result = nil
    loop do
      out, status = Open3.capture2('aws', 'cloudformation', 'describe-stack-drift-detection-status',
                                   '--stack-drift-detection-id', detection_id, '--region', config[:region], '--output', 'json')
      unless status.success?
        puts 'Failed to read drift detection status'
        exit 1
      end
      result = JSON.parse(out)
      break unless result['DetectionStatus'] == 'DETECTION_IN_PROGRESS'

      sleep 3
    end

    puts "Stack drift: #{result['StackDriftStatus']} (#{result['DetectionStatus']})"
    puts "  #{result['DetectionStatusReason']}" if result['DetectionStatus'] == 'DETECTION_FAILED'

    out, status = Open3.capture2('aws', 'cloudformation', 'describe-stack-resource-drifts',
                                 '--stack-name', config[:name], '--region', config[:region],
                                 '--stack-resource-drift-status-filters', 'MODIFIED', 'DELETED', '--output', 'json')
    return unless status.success?

    drifts = JSON.parse(out)['StackResourceDrifts'] || []
    puts '  No resource has drifted.' if drifts.empty?
    drifts.each do |d|
      puts "  #{d['StackResourceDriftStatus'].ljust(9)} #{d['LogicalResourceId']} (#{d['ResourceType']})"
      (d['PropertyDifferences'] || []).each do |pd|
        puts "            #{pd['DifferenceType'].ljust(10)} #{pd['PropertyPath']}"
      end
    end
  end

  def termination_protection(stack_key, enabled)
    config = stack_config(stack_key)
    flag = enabled ? '--enable-termination-protection' : '--no-enable-termination-protection'
    ok = system('aws', 'cloudformation', 'update-termination-protection', flag,
                '--stack-name', config[:name], '--region', config[:region], out: File::NULL)
    unless ok
      puts 'Failed to change termination protection'
      exit 1
    end
    puts "Termination protection on #{config[:name]} is now #{enabled ? 'ON' : 'OFF'}."
  end

  def help
    puts <<~HELP
      CloudFormation Deployment Tool for Everything2

      Usage:
        ./tools/cf-deploy.rb <command> [stack]

      Commands:
        production     Update the main stack (us-west-2): preview the change set,
                       confirm, then execute. Refuses to replace or delete the database
        cloudfront     Deploy CloudFront stack to us-east-1
        status         Show status of all stacks
        outputs [stack] Show stack outputs
        validate [stack] Validate templates
        diff <stack>   Preview changes (a change set, deleted afterwards; changes nothing)
        drift <stack>  List resources whose live configuration differs from the template
        protect <stack>   Turn stack termination protection on
        unprotect <stack> Turn it off (needed only to delete the stack)
        cache-stats    Show CloudFront cache hit rate and metrics
        ecs-status     Show ECS service health and resource utilization
        invalidate [paths] Invalidate CloudFront cache (default: /*)
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
        ./tools/cf-deploy.rb invalidate           # Invalidate all cache
        ./tools/cf-deploy.rb invalidate '/title/*' # Invalidate specific paths

      Notes:
        - CloudFront stack requires production stack to be deployed first
        - ALB domain name is auto-fetched from production stack outputs
        - After deploying CloudFront, update Route53 to point to CF distribution
    HELP
  end
end

CFDeploy.new.run(ARGV) if $PROGRAM_NAME == __FILE__
