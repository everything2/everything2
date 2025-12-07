#!/usr/bin/env ruby
# Query Uninitialized Value Errors from CloudWatch Logs
# Filters by build ID (git commit hash) to show only errors from current/specified build
#
# Usage:
#   ./tools/uninitialized-errors.rb                    # Current build (from last_commit)
#   ./tools/uninitialized-errors.rb --build abc1234   # Specific build
#   ./tools/uninitialized-errors.rb --all             # All builds
#   ./tools/uninitialized-errors.rb --hours 24        # Last 24 hours

require 'json'
require 'optparse'
require 'time'

options = {
  region: 'us-east-1',
  profile: nil,
  build: nil,
  all_builds: false,
  hours: 6,
  limit: 100,
  group_by: 'message'  # message, file, build
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-r", "--region REGION", "AWS region (default: us-east-1)") do |r|
    options[:region] = r
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-b", "--build BUILD_ID", "Filter by build ID (git commit hash)") do |b|
    options[:build] = b
  end

  opts.on("-a", "--all", "Show all builds (don't filter by build ID)") do
    options[:all_builds] = true
  end

  opts.on("-H", "--hours HOURS", Integer, "Hours to look back (default: 6)") do |h|
    options[:hours] = h
  end

  opts.on("-l", "--limit N", Integer, "Max events to retrieve (default: 100)") do |l|
    options[:limit] = l
  end

  opts.on("-g", "--group-by TYPE", "Group by: message, file, build (default: message)") do |g|
    options[:group_by] = g
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "Examples:"
    puts "  #{$0}                           # Current build, last 6 hours"
    puts "  #{$0} --build abc1234           # Specific build"
    puts "  #{$0} --all --hours 24          # All builds, last 24 hours"
    puts "  #{$0} --group-by file           # Group errors by source file"
    puts "  #{$0} --group-by build          # Show error counts per build"
    exit
  end
end.parse!

def aws_cmd(options)
  cmd = "aws"
  cmd += " --profile #{options[:profile]}" if options[:profile]
  cmd += " --region #{options[:region]}"
  cmd
end

def get_current_build
  # Try to read from /etc/everything/last_commit (in container)
  if File.exist?('/etc/everything/last_commit')
    return File.read('/etc/everything/last_commit').strip
  end

  # Fall back to git
  `git rev-parse HEAD 2>/dev/null`.strip
end

def format_time(timestamp_ms)
  return "N/A" if timestamp_ms.nil? || timestamp_ms == 0
  Time.at(timestamp_ms / 1000).strftime("%Y-%m-%d %H:%M:%S")
end

def extract_file_from_message(message)
  # Extract file/line info from "Use of uninitialized value ... at /path/to/file.pm line 123"
  if message =~ /at\s+(\/\S+\.p[lm])\s+line\s+(\d+)/
    "#{$1}:#{$2}"
  elsif message =~ /at\s+(\/\S+)\s+line\s+(\d+)/
    "#{$1}:#{$2}"
  else
    "unknown"
  end
end

def normalize_message(message)
  # Normalize variable names and values to group similar errors
  message
    .gsub(/\$\w+/, '$VAR')           # Replace variable names
    .gsub(/in (?:string|numeric|concatenation|sprintf|pack)/, 'in OPERATION')
    .gsub(/line \d+/, 'line N')      # Normalize line numbers for grouping
end

puts "E2 Uninitialized Value Error Analysis"
puts "=" * 60

# Determine build ID to filter
build_id = nil
unless options[:all_builds]
  build_id = options[:build] || get_current_build
  if build_id.empty?
    puts "Warning: Could not determine current build ID. Use --build or --all"
    build_id = nil
  else
    puts "Build ID: #{build_id[0..6]}... (#{build_id})"
  end
end

# Calculate time range
end_time = (Time.now.to_f * 1000).to_i
start_time = ((Time.now - options[:hours] * 3600).to_f * 1000).to_i
puts "Time range: Last #{options[:hours]} hours"
puts "Region: #{options[:region]}"
puts

# The uninitialized errors go to CloudWatch Logs via EventBridge
# Log group is typically /aws/events/e2-uninitialized or similar
# First, let's find the right log group

log_groups_cmd = "#{aws_cmd(options)} logs describe-log-groups " \
                 "--log-group-name-prefix /aws/events " \
                 "--output json 2>&1"

log_groups_result = `#{log_groups_cmd}`

unless $?.success?
  # Try alternative - direct EventBridge events might be in a different location
  puts "Note: Could not find /aws/events log groups"
  puts "Checking for CloudWatch Logs Insights query capability..."
  puts
end

# Use CloudWatch Logs Insights to query
# The events from com.everything2.uninitialized eventbus get logged somewhere
# Let's try to find logs that contain our error pattern

# First, let's check what log groups exist
puts "Searching for E2 error log groups..."

all_groups_cmd = "#{aws_cmd(options)} logs describe-log-groups --output json"
all_groups_json = `#{all_groups_cmd} 2>&1`

unless $?.success?
  puts "Error: #{all_groups_json}"
  exit 1
end

all_groups = JSON.parse(all_groups_json)['logGroups'] || []

# Look for likely candidates
e2_groups = all_groups.select do |g|
  name = g['logGroupName']
  name.include?('e2') || name.include?('everything') || name.include?('uninitialized') || name.include?('error')
end

if e2_groups.empty?
  puts "No E2-related log groups found."
  puts
  puts "Available log groups:"
  all_groups.first(20).each { |g| puts "  - #{g['logGroupName']}" }
  puts
  puts "The uninitialized errors are sent to CloudWatch Events (EventBridge)"
  puts "event bus 'com.everything2.uninitialized', not CloudWatch Logs."
  puts
  puts "To query EventBridge events, you need to set up a CloudWatch Logs"
  puts "target for the event bus, or use EventBridge archive/replay."
  puts
  puts "Quick setup command:"
  puts "  aws events put-rule --name e2-uninitialized-to-logs \\"
  puts "    --event-bus-name com.everything2.uninitialized \\"
  puts "    --event-pattern '{\"source\":[\"e2.webapp\"]}'"
  puts
  puts "  aws logs create-log-group --log-group-name /aws/events/e2-uninitialized"
  puts
  puts "  aws events put-targets --rule e2-uninitialized-to-logs \\"
  puts "    --event-bus-name com.everything2.uninitialized \\"
  puts "    --targets 'Id=logs,Arn=arn:aws:logs:REGION:ACCOUNT:/aws/events/e2-uninitialized'"
  exit 0
end

puts "Found #{e2_groups.length} potential log groups:"
e2_groups.each { |g| puts "  - #{g['logGroupName']}" }
puts

# Try to query each group for uninitialized errors
events = []

e2_groups.each do |group|
  log_group = group['logGroupName']
  puts "Querying #{log_group}..."

  # Build filter pattern
  filter_pattern = '"Use of uninitialized value"'
  if build_id && !options[:all_builds]
    filter_pattern = "\"Use of uninitialized value\" \"#{build_id[0..6]}\""
  end

  filter_cmd = "#{aws_cmd(options)} logs filter-log-events " \
               "--log-group-name '#{log_group}' " \
               "--start-time #{start_time} " \
               "--end-time #{end_time} " \
               "--filter-pattern '#{filter_pattern}' " \
               "--limit #{options[:limit]} " \
               "--output json 2>&1"

  result = `#{filter_cmd}`

  if $?.success?
    data = JSON.parse(result)
    group_events = data['events'] || []
    puts "  Found #{group_events.length} events"
    events.concat(group_events.map { |e| e.merge('logGroup' => log_group) })
  else
    puts "  Error: #{result[0..100]}..."
  end
end

if events.empty?
  puts
  puts "No uninitialized value errors found in the specified time range."
  puts
  puts "This could mean:"
  puts "  1. No errors occurred (good!)"
  puts "  2. Events are in a different log group"
  puts "  3. EventBridge events aren't being logged to CloudWatch Logs"
  exit 0
end

puts
puts "=" * 60
puts "RESULTS: #{events.length} uninitialized value errors"
puts "=" * 60
puts

# Parse and group events
parsed_events = events.map do |event|
  message = event['message'] || ''

  # Try to parse as JSON (EventBridge format)
  detail = {}
  begin
    parsed = JSON.parse(message)
    detail = parsed['detail'] || parsed
  rescue JSON::ParserError
    detail = { 'message' => message }
  end

  {
    timestamp: event['timestamp'],
    log_group: event['logGroup'],
    message: detail['message'] || message,
    build_id: detail['build_id'] || detail['build_id_short'] || 'unknown',
    build_id_short: (detail['build_id'] || '')[0..6],
    url: detail['url'],
    user: detail['user'],
    node_id: detail['node_id'],
    title: detail['title'],
    callstack: detail['callstack'] || [],
    file: extract_file_from_message(detail['message'] || message)
  }
end

# Filter by build if specified
if build_id && !options[:all_builds]
  short_build = build_id[0..6]
  parsed_events = parsed_events.select { |e| e[:build_id_short] == short_build || e[:build_id] == build_id }
  puts "Filtered to build #{short_build}: #{parsed_events.length} events"
  puts
end

case options[:group_by]
when 'build'
  # Group by build ID
  by_build = parsed_events.group_by { |e| e[:build_id_short] }
  puts "ERRORS BY BUILD:"
  puts "-" * 40
  by_build.sort_by { |_, v| -v.length }.each do |build, evts|
    puts "#{build}: #{evts.length} errors"
  end

when 'file'
  # Group by file
  by_file = parsed_events.group_by { |e| e[:file] }
  puts "ERRORS BY FILE:"
  puts "-" * 40
  by_file.sort_by { |_, v| -v.length }.first(20).each do |file, evts|
    puts
    puts "#{file}: #{evts.length} errors"
    # Show sample messages
    evts.first(3).each do |e|
      puts "  - #{e[:message][0..80]}..."
    end
  end

else  # 'message' (default)
  # Group by normalized message
  by_message = parsed_events.group_by { |e| normalize_message(e[:message]) }
  puts "ERRORS BY MESSAGE (grouped by pattern):"
  puts "-" * 40
  by_message.sort_by { |_, v| -v.length }.first(20).each do |pattern, evts|
    puts
    puts "[#{evts.length}x] #{evts.first[:message][0..100]}"
    puts "     File: #{evts.first[:file]}"
    puts "     URLs: #{evts.map { |e| e[:url] }.compact.uniq.first(3).join(', ')}"
  end
end

puts
puts "=" * 60
puts "RECENT ERRORS (last 10):"
puts "=" * 60

parsed_events.sort_by { |e| -(e[:timestamp] || 0) }.first(10).each do |event|
  puts
  puts "Time: #{format_time(event[:timestamp])}"
  puts "Build: #{event[:build_id_short]}"
  puts "URL: #{event[:url]}" if event[:url]
  puts "User: #{event[:user]}" if event[:user]
  puts "Message: #{event[:message][0..120]}"
  puts "File: #{event[:file]}"
end
