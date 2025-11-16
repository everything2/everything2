#!/usr/bin/env ruby
#
# Everything2 Health Check Diagnostics
# Diagnoses why the E2 app is failing health checks by querying AWS APIs
#
# Usage:
#   ./tools/diagnose-health-checks.rb [options]
#
# Options:
#   --region REGION         AWS region (default: us-west-2)
#   --cluster NAME          ECS cluster name (default: E2-App-ECS-Cluster)
#   --service NAME          ECS service name (default: E2-App-Fargate-Service)
#   --target-group NAME     Target group name (default: E2-App-Fargate-HTTPS-TG)
#   --logs                  Fetch recent CloudWatch logs (slower)
#   --help                  Show this help
#
# Requirements:
#   - AWS CLI configured with credentials
#   - Ruby gems: aws-sdk-ecs, aws-sdk-elasticloadbalancingv2, aws-sdk-cloudwatchlogs
#
# Examples:
#   ./tools/diagnose-health-checks.rb                    # Quick health check
#   ./tools/diagnose-health-checks.rb --logs             # Include log analysis
#

require 'optparse'
require 'time'

# Parse command-line options
options = {
  region: 'us-west-2',
  cluster: 'E2-App-ECS-Cluster',
  service: 'E2-App-Fargate-Service',
  target_group: 'E2-App-Fargate-HTTPS-TG',
  fetch_logs: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: diagnose-health-checks.rb [options]"

  opts.on("--region REGION", String, "AWS region (default: us-west-2)") do |r|
    options[:region] = r
  end

  opts.on("--cluster NAME", String, "ECS cluster name") do |c|
    options[:cluster] = c
  end

  opts.on("--service NAME", String, "ECS service name") do |s|
    options[:service] = s
  end

  opts.on("--target-group NAME", String, "Target group name") do |tg|
    options[:target_group] = tg
  end

  opts.on("--logs", "Fetch recent CloudWatch logs (slower)") do
    options[:fetch_logs] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# Detect development environment - don't make AWS calls if running in dev container
hostname = `hostname`.chomp
if hostname =~ /e2devapp|e2-dev/i || ENV['E2_ENV'] == 'development'
  puts "=" * 80
  puts "❌ Development Environment Detected"
  puts "=" * 80
  puts "This tool is designed to diagnose health check issues in AWS production"
  puts "environments by querying ECS, ELB, and CloudWatch APIs."
  puts
  puts "Detected hostname: #{hostname}"
  puts "Environment: #{ENV['E2_ENV'] || 'not set'}"
  puts
  puts "This tool cannot run in the development container (e2devapp) as it requires:"
  puts "  - AWS credentials configured"
  puts "  - Access to AWS APIs (ECS, ELB, CloudWatch)"
  puts "  - Production ECS cluster and service"
  puts
  puts "To diagnose health checks in production:"
  puts "  1. Run this script from your host machine (not inside the container)"
  puts "  2. Ensure AWS CLI is configured with production credentials"
  puts "  3. Re-run: ./tools/diagnose-health-checks.rb"
  puts
  puts "For local development health check testing, use:"
  puts "  curl http://localhost/health.pl              # Basic check"
  puts "  curl http://localhost/health.pl?detailed=1   # Detailed check"
  puts "  curl http://localhost/health.pl?db=1         # Database check"
  puts "=" * 80
  exit 0
end

# Load AWS SDK gems (only needed in production)
require 'aws-sdk-ecs'
require 'aws-sdk-elasticloadbalancingv2'
require 'aws-sdk-cloudwatchlogs'

# Initialize AWS clients
ecs = Aws::ECS::Client.new(region: options[:region])
elb = Aws::ElasticLoadBalancingV2::Client.new(region: options[:region])
logs = Aws::CloudWatchLogs::Client.new(region: options[:region]) if options[:fetch_logs]

puts "=" * 80
puts "Everything2 Health Check Diagnostics"
puts "=" * 80
puts "Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')}"
puts "Region: #{options[:region]}"
puts "Cluster: #{options[:cluster]}"
puts "Service: #{options[:service]}"
puts "Target Group: #{options[:target_group]}"
puts "=" * 80
puts

# ============================================================================
# 1. ECS Service Status
# ============================================================================
puts "1️⃣  ECS SERVICE STATUS"
puts "-" * 80

begin
  service_resp = ecs.describe_services({
    cluster: options[:cluster],
    services: [options[:service]]
  })

  if service_resp.services.empty?
    puts "❌ ERROR: Service '#{options[:service]}' not found in cluster '#{options[:cluster]}'"
    exit 1
  end

  service = service_resp.services[0]

  puts "Service Name: #{service.service_name}"
  puts "Status: #{service.status}"
  puts "Desired Count: #{service.desired_count}"
  puts "Running Count: #{service.running_count}"
  puts "Pending Count: #{service.pending_count}"
  puts "Health Check Grace Period: #{service.health_check_grace_period_seconds}s"

  if service.running_count == 0
    puts "⚠️  WARNING: No tasks running!"
  elsif service.running_count < service.desired_count
    puts "⚠️  WARNING: Running tasks (#{service.running_count}) < Desired (#{service.desired_count})"
  else
    puts "✓ Task count looks good"
  end

  # Check deployment status
  if service.deployments.length > 1
    puts "\n⚠️  Multiple deployments in progress:"
    service.deployments.each do |deployment|
      puts "  - #{deployment.status}: Desired=#{deployment.desired_count}, Running=#{deployment.running_count}, Pending=#{deployment.pending_count}"
    end
  end

  # Check events for recent failures
  puts "\nRecent Service Events:"
  service.events.first(5).each do |event|
    time = event.created_at.strftime('%Y-%m-%d %H:%M:%S')
    puts "  [#{time}] #{event.message}"
  end

  task_definition_arn = service.task_definition

rescue Aws::ECS::Errors::ServiceError => e
  puts "❌ ERROR querying ECS service: #{e.message}"
  exit 1
end

puts

# ============================================================================
# 2. Running Tasks
# ============================================================================
puts "2️⃣  RUNNING TASKS"
puts "-" * 80

begin
  tasks_resp = ecs.list_tasks({
    cluster: options[:cluster],
    service_name: options[:service],
    desired_status: 'RUNNING'
  })

  if tasks_resp.task_arns.empty?
    puts "❌ No running tasks found!"
  else
    puts "Found #{tasks_resp.task_arns.length} running task(s)\n"

    # Get detailed task information
    tasks_detail = ecs.describe_tasks({
      cluster: options[:cluster],
      tasks: tasks_resp.task_arns
    })

    tasks_detail.tasks.each_with_index do |task, index|
      puts "Task #{index + 1}: #{task.task_arn.split('/').last}"
      puts "  Status: #{task.last_status}"
      puts "  Health: #{task.health_status || 'N/A'}"
      puts "  Started: #{task.started_at ? task.started_at.strftime('%Y-%m-%d %H:%M:%S') : 'N/A'}"
      puts "  Platform: #{task.platform_version}"

      # Container health
      task.containers.each do |container|
        puts "  Container: #{container.name}"
        puts "    Status: #{container.last_status}"
        puts "    Health: #{container.health_status || 'N/A'}"
        if container.exit_code
          puts "    Exit Code: #{container.exit_code}"
        end
        if container.reason
          puts "    Reason: #{container.reason}"
        end
      end

      # Network configuration
      if task.attachments && !task.attachments.empty?
        task.attachments.each do |attachment|
          if attachment.type == 'ElasticNetworkInterface'
            attachment.details.each do |detail|
              if detail.name == 'privateIPv4Address'
                puts "  Private IP: #{detail.value}"
              end
            end
          end
        end
      end

      puts
    end
  end

rescue Aws::ECS::Errors::ServiceError => e
  puts "❌ ERROR querying tasks: #{e.message}"
end

puts

# ============================================================================
# 3. Target Group Health
# ============================================================================
puts "3️⃣  TARGET GROUP HEALTH"
puts "-" * 80

begin
  # Find target group ARN
  tg_resp = elb.describe_target_groups({
    names: [options[:target_group]]
  })

  if tg_resp.target_groups.empty?
    puts "❌ ERROR: Target group '#{options[:target_group]}' not found"
  else
    tg = tg_resp.target_groups[0]
    puts "Target Group: #{tg.target_group_name}"
    puts "Protocol: #{tg.protocol}:#{tg.port}"
    puts "Health Check Protocol: #{tg.health_check_protocol}:#{tg.health_check_port}"
    puts "Health Check Path: #{tg.health_check_path || '/'}"
    puts "Health Check Interval: #{tg.health_check_interval_seconds}s"
    puts "Health Check Timeout: #{tg.health_check_timeout_seconds}s"
    puts "Healthy Threshold: #{tg.healthy_threshold_count}"
    puts "Unhealthy Threshold: #{tg.unhealthy_threshold_count}"
    puts "Matcher: HTTP #{tg.matcher.http_code}" if tg.matcher
    puts

    # Get target health
    health_resp = elb.describe_target_health({
      target_group_arn: tg.target_group_arn
    })

    if health_resp.target_health_descriptions.empty?
      puts "⚠️  No targets registered in target group"
    else
      puts "Registered Targets (#{health_resp.target_health_descriptions.length}):"

      healthy_count = 0
      unhealthy_count = 0

      health_resp.target_health_descriptions.each_with_index do |target_health, index|
        target = target_health.target
        health = target_health.target_health

        status_icon = case health.state
        when 'healthy'
          healthy_count += 1
          '✓'
        when 'unhealthy'
          unhealthy_count += 1
          '✗'
        when 'initial', 'draining'
          '⏳'
        else
          '?'
        end

        puts "\n  #{status_icon} Target #{index + 1}:"
        puts "    IP: #{target.id}"
        puts "    Port: #{target.port}"
        puts "    State: #{health.state}"

        if health.reason
          puts "    Reason: #{health.reason}"
        end

        if health.description
          puts "    Description: #{health.description}"
        end
      end

      puts "\n" + "=" * 40
      puts "Summary: #{healthy_count} healthy, #{unhealthy_count} unhealthy"
      puts "=" * 40

      if unhealthy_count > 0
        puts "\n⚠️  UNHEALTHY TARGETS DETECTED"
        puts "Common causes:"
        puts "  - Application not responding on port 443"
        puts "  - Application returning non-200 status code"
        puts "  - SSL/TLS certificate issues"
        puts "  - Health check timeout (exceeding #{tg.health_check_timeout_seconds}s)"
        puts "  - Application not fully started (within grace period)"
      end
    end
  end

rescue Aws::ElasticLoadBalancingV2::Errors::ServiceError => e
  puts "❌ ERROR querying target group: #{e.message}"
end

puts

# ============================================================================
# 4. Task Definition Health Check
# ============================================================================
puts "4️⃣  TASK DEFINITION HEALTH CHECK"
puts "-" * 80

begin
  td_resp = ecs.describe_task_definition({
    task_definition: task_definition_arn
  })

  td = td_resp.task_definition
  puts "Task Definition: #{td.family}:#{td.revision}"
  puts "Status: #{td.status}"
  puts "Requires Compatibilities: #{td.requires_compatibilities.join(', ')}"
  puts "CPU: #{td.cpu}"
  puts "Memory: #{td.memory}"
  puts

  td.container_definitions.each do |container|
    puts "Container: #{container.name}"
    puts "  Image: #{container.image}"

    if container.health_check
      puts "  Health Check Command: #{container.health_check.command.join(' ')}"
      puts "  Interval: #{container.health_check.interval}s"
      puts "  Timeout: #{container.health_check.timeout}s"
      puts "  Retries: #{container.health_check.retries}"
      puts "  Start Period: #{container.health_check.start_period}s"
    else
      puts "  ⚠️  No container-level health check defined"
    end

    if container.port_mappings && !container.port_mappings.empty?
      puts "  Port Mappings:"
      container.port_mappings.each do |pm|
        puts "    - Container: #{pm.container_port}, Host: #{pm.host_port || 'dynamic'}, Protocol: #{pm.protocol}"
      end
    end
    puts
  end

rescue Aws::ECS::Errors::ServiceError => e
  puts "❌ ERROR querying task definition: #{e.message}"
end

puts

# ============================================================================
# 5. Recent CloudWatch Logs (Optional)
# ============================================================================
if options[:fetch_logs]
  puts "5️⃣  RECENT CLOUDWATCH LOGS"
  puts "-" * 80

  begin
    # Determine log group name (typically /ecs/<family>)
    log_group = "/ecs/#{td_resp.task_definition.family}"

    puts "Log Group: #{log_group}"
    puts "Fetching last 20 log events from the last 10 minutes...\n"

    # Get log streams
    streams_resp = logs.describe_log_streams({
      log_group_name: log_group,
      order_by: 'LastEventTime',
      descending: true,
      limit: 5
    })

    if streams_resp.log_streams.empty?
      puts "⚠️  No log streams found"
    else
      # Get recent events from the most recent stream
      stream = streams_resp.log_streams[0]

      events_resp = logs.get_log_events({
        log_group_name: log_group,
        log_stream_name: stream.log_stream_name,
        start_time: ((Time.now - 600) * 1000).to_i,  # Last 10 minutes
        limit: 20
      })

      if events_resp.events.empty?
        puts "No recent log events found"
      else
        events_resp.events.reverse.each do |event|
          timestamp = Time.at(event.timestamp / 1000).strftime('%Y-%m-%d %H:%M:%S')
          puts "[#{timestamp}] #{event.message}"
        end
      end
    end

  rescue Aws::CloudWatchLogs::Errors::ResourceNotFoundException
    puts "⚠️  Log group '#{log_group}' not found"
  rescue Aws::CloudWatchLogs::Errors::ServiceError => e
    puts "❌ ERROR fetching logs: #{e.message}"
  end

  puts
end

# ============================================================================
# Summary and Recommendations
# ============================================================================
puts "=" * 80
puts "DIAGNOSTIC SUMMARY"
puts "=" * 80

recommendations = []

# Check if tasks are running
if service.running_count == 0
  recommendations << "🔴 CRITICAL: No tasks running. Check service events and task failures."
elsif service.running_count < service.desired_count
  recommendations << "🟡 WARNING: Running tasks below desired count. Check for task startup issues."
end

# Check target health
if defined?(unhealthy_count) && unhealthy_count > 0
  recommendations << "🔴 CRITICAL: Unhealthy targets detected. Application may not be responding correctly."
elsif defined?(healthy_count) && healthy_count == 0
  recommendations << "🔴 CRITICAL: No healthy targets. Check application health check endpoint."
end

# Check for multiple deployments
if service.deployments.length > 1
  recommendations << "🟡 WARNING: Multiple deployments in progress. Wait for deployment to complete."
end

if recommendations.empty?
  puts "✅ No major issues detected!"
  puts "\nIf you're still experiencing problems:"
  puts "  1. Check application logs for errors"
  puts "  2. Verify SSL certificate is valid"
  puts "  3. Test health check endpoint manually: curl -k https://<task-ip>/"
  puts "  4. Review recent deployments for changes"
else
  puts "Issues Found:\n"
  recommendations.each do |rec|
    puts "  #{rec}"
  end

  puts "\nNext Steps:"
  puts "  1. Review service events above for specific error messages"
  puts "  2. Check task logs: aws logs tail /ecs/#{td_resp.task_definition.family} --follow"
  puts "  3. Verify health check configuration matches application"
  puts "  4. Consider increasing health check timeout or grace period"
  puts "  5. Test application manually from within VPC"
end

puts "=" * 80
