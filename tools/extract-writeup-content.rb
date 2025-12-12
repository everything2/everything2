#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract Writeup Content for Link Parsing Analysis
#
# Runs the cron_extract_writeup_content.pl script in production via ECS Fargate,
# then downloads the resulting JSON files from S3 for local analysis.
#
# Usage:
#   ./tools/extract-writeup-content.rb                    # Run extraction and download
#   ./tools/extract-writeup-content.rb --download-only    # Just download existing files
#   ./tools/extract-writeup-content.rb --status           # Check task status
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - CloudFormation stack deployed with WriteupExportBucket
#   - everything.conf.json on production has writeup_export s3 config

require 'json'
require 'optparse'
require 'open3'
require 'fileutils'

REGION = 'us-west-2'
BUCKET = 'e2-writeup-exports'
CLUSTER = 'E2-App-Cluster'
TASK_FAMILY = 'e2cron-family'
CRON_SCRIPT = '/var/everything/cron/cron_extract_writeup_content.pl'
OUTPUT_DIR = 'tmp/writeup-exports'

options = {
  download_only: false,
  status: false,
  wait: true,
  profile: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-d", "--download-only", "Just download existing S3 files (skip ECS task)") do
    options[:download_only] = true
  end

  opts.on("-s", "--status", "Check status of running task") do
    options[:status] = true
  end

  opts.on("--no-wait", "Don't wait for task completion (just start it)") do
    options[:wait] = false
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "This tool runs the writeup content extraction cron job in production"
    puts "and downloads the resulting JSON files for link parsing analysis."
    puts
    puts "Output files are saved to: #{OUTPUT_DIR}/"
    puts "  - writeup-content-sample.json  (1000 random writeups)"
    puts "  - writeup-content-recent.json  (last 30 days)"
    puts "  - writeup-content-full.json.gz (all writeups, compressed)"
    puts "  - manifest.json                (export metadata)"
    puts
    puts "After downloading, analyze with:"
    puts "  node tools/compare-link-parsing.js #{OUTPUT_DIR}/writeup-content-sample.json"
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

def get_vpc_config(options)
  # Get the ECS service to find its network configuration
  result = run_aws(options, "ecs", "describe-services",
                   "--cluster", CLUSTER,
                   "--services", "E2-App-Fargate-Service")

  return nil unless result && result['services']&.any?

  service = result['services'].first
  network_config = service.dig('networkConfiguration', 'awsvpcConfiguration')

  return nil unless network_config

  {
    subnets: network_config['subnets'],
    security_groups: network_config['securityGroups'],
    assign_public_ip: network_config['assignPublicIp']
  }
end

def run_ecs_task(options)
  puts "Getting VPC configuration from existing service..."
  vpc_config = get_vpc_config(options)

  unless vpc_config
    STDERR.puts "Error: Could not get VPC configuration from ECS service"
    exit 1
  end

  puts "  Subnets: #{vpc_config[:subnets].join(', ')}"
  puts "  Security Groups: #{vpc_config[:security_groups].join(', ')}"
  puts

  puts "Starting ECS task..."

  # Build the network configuration JSON
  network_config = {
    awsvpcConfiguration: {
      subnets: vpc_config[:subnets],
      securityGroups: vpc_config[:security_groups],
      assignPublicIp: vpc_config[:assign_public_ip]
    }
  }

  # Build command override to run the cron script
  overrides = {
    containerOverrides: [
      {
        name: "e2app",
        command: ["perl", CRON_SCRIPT]
      }
    ]
  }

  result = run_aws(options, "ecs", "run-task",
                   "--cluster", CLUSTER,
                   "--task-definition", TASK_FAMILY,
                   "--launch-type", "FARGATE",
                   "--network-configuration", network_config.to_json,
                   "--overrides", overrides.to_json)

  unless result && result['tasks']&.any?
    STDERR.puts "Error: Failed to start ECS task"
    STDERR.puts result.inspect if result
    exit 1
  end

  task = result['tasks'].first
  task_arn = task['taskArn']
  task_id = task_arn.split('/').last

  puts "Task started: #{task_id}"
  puts "Task ARN: #{task_arn}"

  task_id
end

def wait_for_task(options, task_id)
  puts
  puts "Waiting for task to complete..."
  puts "(This may take several minutes for large exports)"
  puts

  start_time = Time.now
  last_status = nil

  loop do
    result = run_aws(options, "ecs", "describe-tasks",
                     "--cluster", CLUSTER,
                     "--tasks", task_id)

    unless result && result['tasks']&.any?
      STDERR.puts "Error: Could not get task status"
      exit 1
    end

    task = result['tasks'].first
    status = task['lastStatus']
    elapsed = (Time.now - start_time).to_i

    if status != last_status
      puts "[#{elapsed}s] Status: #{status}"
      last_status = status
    end

    case status
    when 'STOPPED'
      stop_reason = task['stoppedReason']
      exit_code = task.dig('containers', 0, 'exitCode')

      puts
      if exit_code == 0
        puts "Task completed successfully!"
      else
        puts "Task stopped: #{stop_reason}"
        puts "Exit code: #{exit_code}"
        exit 1 unless exit_code == 0
      end
      break

    when 'RUNNING'
      # Show a progress indicator
      print "." if elapsed % 10 == 0
    end

    sleep 5
  end
end

def check_task_status(options)
  puts "Checking for running tasks..."

  result = run_aws(options, "ecs", "list-tasks",
                   "--cluster", CLUSTER,
                   "--family", TASK_FAMILY)

  unless result
    STDERR.puts "Error: Could not list tasks"
    exit 1
  end

  task_arns = result['taskArns'] || []

  if task_arns.empty?
    puts "No tasks currently running for #{TASK_FAMILY}"
    return
  end

  result = run_aws(options, "ecs", "describe-tasks",
                   "--cluster", CLUSTER,
                   "--tasks", *task_arns)

  tasks = result['tasks'] || []

  puts "Found #{tasks.length} task(s):"
  puts

  tasks.each do |task|
    task_id = task['taskArn'].split('/').last
    status = task['lastStatus']
    created = task['createdAt']
    started = task['startedAt']
    stopped = task['stoppedAt']

    puts "Task: #{task_id}"
    puts "  Status: #{status}"
    puts "  Created: #{created}"
    puts "  Started: #{started}" if started
    puts "  Stopped: #{stopped}" if stopped

    if status == 'STOPPED'
      puts "  Stop reason: #{task['stoppedReason']}"
      exit_code = task.dig('containers', 0, 'exitCode')
      puts "  Exit code: #{exit_code}"
    end
    puts
  end
end

def download_from_s3(options)
  FileUtils.mkdir_p(OUTPUT_DIR)

  puts "Downloading files from S3 bucket: #{BUCKET}"
  puts "Output directory: #{OUTPUT_DIR}"
  puts

  files = [
    'manifest.json',
    'writeup-content-sample.json',
    'writeup-content-recent.json',
    'writeup-content-full.json.gz'
  ]

  files.each do |file|
    local_path = File.join(OUTPUT_DIR, file)
    s3_path = "s3://#{BUCKET}/#{file}"

    print "  #{file}... "

    cmd = aws_cmd(options) + ["s3", "cp", s3_path, local_path]
    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success?
      size = File.size(local_path)
      puts "OK (#{format_bytes(size)})"
    else
      puts "FAILED"
      STDERR.puts "    #{stderr.strip}" unless stderr.empty?
    end
  end

  puts
  puts "Download complete!"
  puts

  # Show manifest if available
  manifest_path = File.join(OUTPUT_DIR, 'manifest.json')
  if File.exist?(manifest_path)
    manifest = JSON.parse(File.read(manifest_path))
    puts "Export Manifest:"
    puts "  Generated: #{manifest['generated_at']}"
    puts "  Total writeups: #{manifest.dig('statistics', 'total_writeups')}"
    puts "  With links: #{manifest.dig('statistics', 'with_links')}"
    puts "  Avg length: #{manifest.dig('statistics', 'average_length')} chars"
    puts

    puts "Files:"
    manifest['files']&.each do |name, info|
      puts "  #{name}: #{info['count']} writeups (#{format_bytes(info['size_bytes'])})"
    end
  end

  puts
  puts "To analyze edge cases, run:"
  puts "  node tools/compare-link-parsing.js #{OUTPUT_DIR}/writeup-content-sample.json"
end

def format_bytes(bytes)
  return "0 B" if bytes.nil? || bytes == 0

  units = ['B', 'KB', 'MB', 'GB', 'TB']
  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = units.length - 1 if exp >= units.length

  format("%.2f %s", bytes.to_f / (1024**exp), units[exp])
end

# Main execution
puts "Writeup Content Extraction Tool"
puts "=" * 60
puts

if options[:status]
  check_task_status(options)
elsif options[:download_only]
  download_from_s3(options)
else
  task_id = run_ecs_task(options)

  if options[:wait]
    wait_for_task(options, task_id)
    puts
    download_from_s3(options)
  else
    puts
    puts "Task started in background."
    puts "Check status with: ./tools/extract-writeup-content.rb --status"
    puts "Download results with: ./tools/extract-writeup-content.rb --download-only"
  end
end
