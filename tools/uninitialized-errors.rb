#!/usr/bin/env ruby
# Query Uninitialized Value Errors from CloudWatch Logs
#
# Usage:
#   ./tools/uninitialized-errors.rb                    # Last 6 hours
#   ./tools/uninitialized-errors.rb --hours 24        # Last 24 hours
#   ./tools/uninitialized-errors.rb --build f113da0   # Filter by build
#   ./tools/uninitialized-errors.rb --since-commit    # Since current commit time
#   ./tools/uninitialized-errors.rb --group-by file   # Group by source file

require 'json'
require 'optparse'
require 'time'

LOG_GROUP = '/aws/events/e2-uninitialized-errors'

options = {
  region: 'us-west-2',
  profile: nil,
  build: nil,
  hours: 6,
  since_commit: false,
  limit: 100,
  group_by: 'message'  # message, file, url, build
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-r", "--region REGION", "AWS region (default: us-west-2)") do |r|
    options[:region] = r
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-b", "--build BUILD_ID", "Filter by build ID (full or short hash)") do |b|
    options[:build] = b
  end

  opts.on("-H", "--hours HOURS", Integer, "Hours to look back (default: 6)") do |h|
    options[:hours] = h
  end

  opts.on("-s", "--since-commit [COMMIT]", "Look back since commit time (default: HEAD)") do |c|
    options[:since_commit] = c || 'HEAD'
  end

  opts.on("-l", "--limit N", Integer, "Max events to retrieve (default: 100)") do |l|
    options[:limit] = l
  end

  opts.on("-g", "--group-by TYPE", "Group by: message, file, url, build (default: message)") do |g|
    options[:group_by] = g
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "Examples:"
    puts "  #{$0}                           # Last 6 hours"
    puts "  #{$0} --hours 24                # Last 24 hours"
    puts "  #{$0} --since-commit            # Since HEAD commit time"
    puts "  #{$0} --since-commit abc1234    # Since specific commit time"
    puts "  #{$0} --build f113da0           # Filter by build"
    puts "  #{$0} --group-by file           # Group errors by source file"
    puts "  #{$0} --group-by url            # Group errors by URL"
    puts "  #{$0} --group-by build          # Show error counts per build"
    puts "  #{$0} --limit 500               # Get more events"
    exit
  end
end.parse!

def aws_cmd(options)
  cmd = "aws"
  cmd += " --profile #{options[:profile]}" if options[:profile]
  cmd += " --region #{options[:region]}"
  cmd
end

def get_commit_time(commit_ref)
  # Get Unix timestamp of a commit
  timestamp = `git log -1 --format='%ct' #{commit_ref} 2>/dev/null`.strip
  return nil if timestamp.empty?
  timestamp.to_i
end

def get_commit_short_hash(commit_ref)
  # Match the 7-char format used in production build_id_short
  hash = `git log -1 --format='%H' #{commit_ref} 2>/dev/null`.strip
  hash[0..6]
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
    .gsub(/in (?:string|numeric|concatenation|sprintf|pack|substitution|pattern match|exists)/, 'in OPERATION')
    .gsub(/line \d+/, 'line N')      # Normalize line numbers for grouping
end

def short_url(url)
  return 'N/A' unless url
  url.gsub('https://everything2.com', '').gsub('https://www.everything2.com', '').gsub('http://localhost:9080', '')[0..60]
end

puts "E2 Uninitialized Value Error Analysis"
puts "=" * 60
puts "Log group: #{LOG_GROUP}"
puts "Region: #{options[:region]}"

# Calculate time range
end_time = (Time.now.to_f * 1000).to_i
start_time = nil
time_description = nil

if options[:since_commit]
  commit_time = get_commit_time(options[:since_commit])
  if commit_time
    start_time = commit_time * 1000
    commit_hash = get_commit_short_hash(options[:since_commit])
    time_description = "Since commit #{commit_hash} (#{Time.at(commit_time).strftime('%Y-%m-%d %H:%M:%S')})"
    # Auto-set build filter if not specified
    options[:build] ||= commit_hash
  else
    puts "Error: Could not find commit '#{options[:since_commit]}'"
    exit 1
  end
else
  start_time = ((Time.now - options[:hours] * 3600).to_f * 1000).to_i
  time_description = "Last #{options[:hours]} hours"
end

puts "Time range: #{time_description}"
puts "Build filter: #{options[:build] || 'none'}"
puts "Limit: #{options[:limit]} events"
puts

# Build filter pattern - include build_id_short if filtering by build
# Uses CloudWatch JSON filter pattern syntax
filter_pattern = nil
if options[:build]
  # Filter by build_id_short in the JSON detail object
  filter_pattern = '{ $.detail.build_id_short = "' + options[:build] + '" }'
end

# Query the log group directly
filter_cmd = "#{aws_cmd(options)} logs filter-log-events " \
             "--log-group-name '#{LOG_GROUP}' " \
             "--start-time #{start_time} " \
             "--end-time #{end_time} " \
             "--limit #{options[:limit]} " \
             "--output json"
filter_cmd += " --filter-pattern '#{filter_pattern}'" if filter_pattern
filter_cmd += " 2>&1"

puts "Querying CloudWatch Logs..."
result = `#{filter_cmd}`

unless $?.success?
  puts "Error querying logs:"
  puts result
  exit 1
end

data = JSON.parse(result)
events = data['events'] || []

if events.empty?
  puts
  puts "No uninitialized value errors found in the specified time range."
  puts
  puts "This is good news! No warnings were logged."
  exit 0
end

puts "Found #{events.length} events"
puts

# Parse events from EventBridge JSON format
parsed_events = events.map do |event|
  message = event['message'] || ''

  # Parse EventBridge JSON wrapper
  detail = {}
  begin
    parsed = JSON.parse(message)
    detail = parsed['detail'] || {}
  rescue JSON::ParserError
    detail = { 'message' => message }
  end

  {
    timestamp: event['timestamp'],
    message: detail['message'] || message,
    url: detail['url'],
    user: detail['user'],
    request_method: detail['request_method'],
    params: detail['params'] || {},
    callstack: detail['callstack'] || [],
    build_id: detail['build_id'],
    build_id_short: detail['build_id_short'] || (detail['build_id'] ? detail['build_id'][0..6] : 'unknown'),
    file: extract_file_from_message(detail['message'] || message)
  }
end

puts "=" * 60
puts "RESULTS: #{parsed_events.length} uninitialized value errors"
puts "=" * 60
puts

case options[:group_by]
when 'build'
  # Group by build
  by_build = parsed_events.group_by { |e| e[:build_id_short] }
  puts "ERRORS BY BUILD:"
  puts "-" * 40
  by_build.sort_by { |_, v| -v.length }.each do |build, evts|
    puts
    puts "#{build}: #{evts.length} errors"
    # Show top files for this build
    files = evts.group_by { |e| e[:file] }.sort_by { |_, v| -v.length }.first(3)
    files.each { |f, e| puts "  #{f}: #{e.length}" }
  end

when 'file'
  # Group by file
  by_file = parsed_events.group_by { |e| e[:file] }
  puts "ERRORS BY FILE:"
  puts "-" * 40
  by_file.sort_by { |_, v| -v.length }.first(20).each do |file, evts|
    puts
    puts "#{file}: #{evts.length} errors"
    # Show sample URLs
    urls = evts.map { |e| short_url(e[:url]) }.compact.uniq.first(3)
    puts "  Sample URLs: #{urls.join(', ')}" unless urls.empty?
  end

when 'url'
  # Group by URL (normalized)
  by_url = parsed_events.group_by { |e| short_url(e[:url]) }
  puts "ERRORS BY URL:"
  puts "-" * 40
  by_url.sort_by { |_, v| -v.length }.first(20).each do |url, evts|
    puts
    puts "[#{evts.length}x] #{url}"
    # Show files involved
    files = evts.map { |e| e[:file] }.uniq.first(3)
    puts "  Files: #{files.join(', ')}"
  end

else  # 'message' (default)
  # Group by normalized message
  by_message = parsed_events.group_by { |e| normalize_message(e[:message]) }
  puts "ERRORS BY MESSAGE (grouped by pattern):"
  puts "-" * 40
  by_message.sort_by { |_, v| -v.length }.first(20).each do |pattern, evts|
    puts
    puts "[#{evts.length}x] #{evts.first[:message].strip[0..100]}"
    puts "     File: #{evts.first[:file]}"
    urls = evts.map { |e| short_url(e[:url]) }.compact.uniq.first(3)
    puts "     URLs: #{urls.join(', ')}" unless urls.empty?
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
  puts "URL: #{short_url(event[:url])}" if event[:url]
  puts "User: #{event[:user]}" if event[:user]
  puts "Message: #{event[:message].strip[0..100]}"
  puts "File: #{event[:file]}"
  if event[:callstack] && !event[:callstack].empty?
    # Show just the relevant E2 stack frames
    e2_frames = event[:callstack].select { |f| f.include?('/var/everything/') }.last(3)
    unless e2_frames.empty?
      puts "Stack: #{e2_frames.join(' <- ')}"
    end
  end
end
