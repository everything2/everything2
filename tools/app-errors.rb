#!/usr/bin/env ruby
# Query Application Errors from CloudWatch Logs
#
# This tool analyzes the e2-app-errors log group which captures all warnings
# and errors from the E2 Perl application (excluding "uninitialized value"
# warnings which go to a separate log group).
#
# Usage:
#   ./tools/app-errors.rb                     # Last 6 hours, summary view
#   ./tools/app-errors.rb --hours 24          # Last 24 hours
#   ./tools/app-errors.rb --days 7            # Last 7 days
#   ./tools/app-errors.rb --errors-only       # Only DIE handler errors (not warnings)
#   ./tools/app-errors.rb --group-by file     # Group by source file
#   ./tools/app-errors.rb --group-by url      # Group by URL
#   ./tools/app-errors.rb --verbose           # Show full error details
#   ./tools/app-errors.rb --actionable        # Show only actionable E2 code errors

require 'json'
require 'optparse'
require 'time'

LOG_GROUP = '/aws/events/e2-app-errors'

options = {
  region: 'us-west-2',
  profile: nil,
  hours: 6,
  days: nil,
  limit: 500,
  group_by: 'message',  # message, file, url, type
  errors_only: false,
  actionable: false,
  verbose: false,
  build: nil,
  since_commit: false
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-r", "--region REGION", "AWS region (default: us-west-2)") do |r|
    options[:region] = r
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-H", "--hours HOURS", Integer, "Hours to look back (default: 6)") do |h|
    options[:hours] = h
  end

  opts.on("-d", "--days DAYS", Integer, "Days to look back (overrides --hours)") do |d|
    options[:days] = d
  end

  opts.on("-l", "--limit N", Integer, "Max events to retrieve (default: 500)") do |l|
    options[:limit] = l
  end

  opts.on("-g", "--group-by TYPE", "Group by: message, file, url, type (default: message)") do |g|
    options[:group_by] = g
  end

  opts.on("-e", "--errors-only", "Show only DIE handler errors (not warnings)") do
    options[:errors_only] = true
  end

  opts.on("-a", "--actionable", "Show only actionable E2 code errors (excludes library issues)") do
    options[:actionable] = true
  end

  opts.on("-v", "--verbose", "Show full error details with callstacks") do
    options[:verbose] = true
  end

  opts.on("-b", "--build BUILD_ID", "Filter by build ID (full or short hash)") do |b|
    options[:build] = b
  end

  opts.on("-s", "--since-commit [COMMIT]", "Look back since commit time (default: HEAD)") do |c|
    options[:since_commit] = c || 'HEAD'
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "Examples:"
    puts "  #{$0}                           # Summary of last 6 hours"
    puts "  #{$0} --hours 24                # Last 24 hours"
    puts "  #{$0} --days 7                  # Last 7 days"
    puts "  #{$0} --since-commit            # Since HEAD commit time (auto-filters by build)"
    puts "  #{$0} --since-commit abc1234    # Since specific commit time"
    puts "  #{$0} --errors-only             # Only fatal errors (DIE handler)"
    puts "  #{$0} --actionable              # Only errors in E2 code"
    puts "  #{$0} --group-by file           # Group by source file"
    puts "  #{$0} --group-by url            # Group errors by URL"
    puts "  #{$0} --group-by type           # Show error/warning counts by type"
    puts "  #{$0} --verbose                 # Include full callstacks"
    puts
    puts "Error Types:"
    puts "  - warning: Perl warnings captured by __WARN__ handler"
    puts "  - error: Fatal errors captured by __DIE__ handler"
    puts
    puts "Common Error Patterns:"
    puts "  - \"Argument X isn't numeric\" - SQL injection attempts or bad input"
    puts "  - \"Can't call method on undefined\" - Null reference errors"
    puts "  - \"CGI::param called in list context\" - Security warning"
    puts "  - \"Parsing of undecoded UTF-8\" - Encoding issues"
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

def relative_time(timestamp_ms)
  return "N/A" if timestamp_ms.nil? || timestamp_ms == 0
  seconds_ago = Time.now.to_i - (timestamp_ms / 1000)
  if seconds_ago < 60
    "#{seconds_ago}s ago"
  elsif seconds_ago < 3600
    "#{seconds_ago / 60}m ago"
  elsif seconds_ago < 86400
    "#{seconds_ago / 3600}h ago"
  else
    "#{seconds_ago / 86400}d ago"
  end
end

def extract_file_from_message(message)
  # Extract file/line info from "... at /path/to/file.pm line 123"
  if message =~ /at\s+(\/\S+\.p[lm])\s+line\s+(\d+)/
    "#{$1}:#{$2}"
  elsif message =~ /at\s+(\/\S+)\s+line\s+(\d+)/
    "#{$1}:#{$2}"
  else
    "unknown"
  end
end

def extract_file_short(file_path)
  # Shorten paths for display
  file_path
    .gsub('/var/everything/ecore/', '')
    .gsub('/var/everything/', '')
    .gsub('/var/libraries/lib/perl5/', 'lib/')
end

def short_url(url)
  return 'N/A' unless url
  url.gsub('https://everything2.com', '').gsub('http://everything2.com', '').gsub('http://localhost:9080', '')[0..60]
end

def normalize_message(message)
  # Normalize variable values to group similar errors
  message
    .gsub(/Argument ".*?" isn't numeric/, 'Argument "X" isn\'t numeric')
    .gsub(/line \d+/, 'line N')
    .gsub(/node_id=\d+/, 'node_id=N')
    .gsub(/\d{4,}/, 'N')  # Large numbers
end

def categorize_error(message, file)
  # Categorize errors for prioritization
  return :sql_injection if message =~ /isn't numeric.*eq.*\(==\)/
  return :null_reference if message =~ /Can't call method.*on an undefined/
  return :encoding if message =~ /UTF-8|encoding|undecoded/
  return :cgi_security if message =~ /CGI::param.*list context/
  return :library_issue if file =~ /\/var\/libraries\/|\/usr\/share\/perl/
  return :external_api if message =~ /SSL|HTTP::Tiny|LWP/
  :application
end

def is_e2_code?(file)
  file.include?('/var/everything/') && !file.include?('/var/libraries/')
end

# ANSI colors for terminal output
class String
  def red;     "\e[31m#{self}\e[0m" end
  def yellow;  "\e[33m#{self}\e[0m" end
  def green;   "\e[32m#{self}\e[0m" end
  def cyan;    "\e[36m#{self}\e[0m" end
  def bold;    "\e[1m#{self}\e[0m" end
  def dim;     "\e[2m#{self}\e[0m" end
end

puts "E2 Application Error Analysis".bold
puts "=" * 70

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
    puts "Error: Could not find commit '#{options[:since_commit]}'".red
    exit 1
  end
elsif options[:days]
  start_time = ((Time.now - options[:days] * 86400).to_f * 1000).to_i
  time_description = "Last #{options[:days]} days"
else
  start_time = ((Time.now - options[:hours] * 3600).to_f * 1000).to_i
  time_description = "Last #{options[:hours]} hours"
end

puts "Log group: #{LOG_GROUP}"
puts "Time range: #{time_description}"
puts "Limit: #{options[:limit]} events"
puts "Filters: #{[options[:errors_only] ? 'errors-only' : nil, options[:actionable] ? 'actionable' : nil, options[:build] ? "build=#{options[:build]}" : nil].compact.join(', ') || 'none'}"
puts

# Build filter pattern
filter_pattern = nil
if options[:errors_only]
  filter_pattern = '{ $.detail.type = "error" }'
elsif options[:build]
  filter_pattern = '{ $.detail.build_id_short = "' + options[:build] + '" }'
end

# Query CloudWatch Logs
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
  puts "Error querying logs:".red
  puts result
  exit 1
end

data = JSON.parse(result)
events = data['events'] || []

if events.empty?
  puts
  puts "No application errors found in the specified time range.".green
  puts "This is good news!"
  exit 0
end

puts "Found #{events.length} raw events"

# Parse events
parsed_events = events.map do |event|
  message_raw = event['message'] || ''

  detail = {}
  begin
    parsed = JSON.parse(message_raw)
    detail = parsed['detail'] || {}
  rescue JSON::ParserError
    detail = { 'message' => message_raw }
  end

  file = extract_file_from_message(detail['message'] || message_raw)

  {
    timestamp: event['timestamp'],
    message: detail['message'] || message_raw,
    url: detail['url'],
    user: detail['user'],
    request_method: detail['request_method'],
    params: detail['params'] || {},
    callstack: detail['callstack'] || [],
    build_id: detail['build_id'],
    build_id_short: detail['build_id_short'] || 'unknown',
    type: detail['type'] || 'unknown',
    file: file,
    file_short: extract_file_short(file),
    category: categorize_error(detail['message'] || message_raw, file),
    is_e2_code: is_e2_code?(file)
  }
end

# Filter for actionable if requested
if options[:actionable]
  parsed_events = parsed_events.select { |e| e[:is_e2_code] && e[:category] != :library_issue }
  puts "After actionable filter: #{parsed_events.length} events"
end

if parsed_events.empty?
  puts
  puts "No matching errors found after filtering.".green
  exit 0
end

puts
puts "=" * 70
puts "SUMMARY".bold
puts "=" * 70
puts

# Show type breakdown
by_type = parsed_events.group_by { |e| e[:type] }
puts "By Type:"
by_type.each do |type, evts|
  color = type == 'error' ? :red : :yellow
  puts "  #{type}: #{evts.length}".send(color)
end
puts

# Show category breakdown
by_category = parsed_events.group_by { |e| e[:category] }
puts "By Category:"
by_category.sort_by { |_, v| -v.length }.each do |cat, evts|
  puts "  #{cat}: #{evts.length}"
end
puts

puts "=" * 70
case options[:group_by]
when 'type'
  puts "ERRORS BY TYPE".bold
  puts "=" * 70

  by_type.sort_by { |_, v| -v.length }.each do |type, evts|
    puts
    header = "#{type.upcase}: #{evts.length} events"
    puts (type == 'error' ? header.red.bold : header.yellow.bold)

    # Show top messages for this type
    by_msg = evts.group_by { |e| normalize_message(e[:message]) }
    by_msg.sort_by { |_, v| -v.length }.first(5).each do |_, samples|
      sample = samples.first
      puts "  [#{samples.length}x] #{sample[:message].strip[0..70]}"
      puts "         File: #{sample[:file_short]}"
    end
  end

when 'file'
  puts "ERRORS BY FILE".bold
  puts "=" * 70

  by_file = parsed_events.group_by { |e| e[:file_short] }
  by_file.sort_by { |_, v| -v.length }.first(20).each do |file, evts|
    puts
    is_e2 = evts.first[:is_e2_code]
    header = "[#{evts.length}x] #{file}"
    puts (is_e2 ? header.cyan : header.dim)

    # Show sample messages
    messages = evts.map { |e| e[:message].strip[0..60] }.uniq.first(2)
    messages.each { |m| puts "       #{m}" }

    # Show sample URLs
    urls = evts.map { |e| short_url(e[:url]) }.compact.uniq.first(2)
    puts "       URLs: #{urls.join(', ')}" unless urls.empty?
  end

when 'url'
  puts "ERRORS BY URL".bold
  puts "=" * 70

  by_url = parsed_events.group_by { |e| short_url(e[:url]) }
  by_url.sort_by { |_, v| -v.length }.first(20).each do |url, evts|
    puts
    puts "[#{evts.length}x] #{url}".cyan

    # Show files and messages
    files = evts.map { |e| e[:file_short] }.uniq.first(3)
    puts "       Files: #{files.join(', ')}"

    messages = evts.group_by { |e| normalize_message(e[:message]) }
    messages.sort_by { |_, v| -v.length }.first(2).each do |_, samples|
      puts "       - #{samples.first[:message].strip[0..50]}"
    end
  end

else  # 'message' (default)
  puts "ERRORS BY MESSAGE (grouped by pattern)".bold
  puts "=" * 70

  by_message = parsed_events.group_by { |e| normalize_message(e[:message]) }
  by_message.sort_by { |_, v| -v.length }.first(20).each do |pattern, evts|
    puts
    sample = evts.first
    count_str = "[#{evts.length}x]"
    type_indicator = sample[:type] == 'error' ? '!'.red : 'W'.yellow

    puts "#{count_str.bold} #{type_indicator} #{sample[:message].strip[0..65]}"
    puts "     File: #{sample[:file_short]}"
    puts "     Category: #{sample[:category]}"

    urls = evts.map { |e| short_url(e[:url]) }.compact.uniq.first(3)
    puts "     URLs: #{urls.join(', ')}" unless urls.empty?

    if options[:verbose] && sample[:callstack] && !sample[:callstack].empty?
      e2_frames = sample[:callstack].select { |f| f.include?('/var/everything/') }.last(4)
      unless e2_frames.empty?
        puts "     Stack:"
        e2_frames.each { |f| puts "       - #{extract_file_short(f)}" }
      end
    end
  end
end

# Show recent errors
puts
puts "=" * 70
puts "MOST RECENT ERRORS (last 10)".bold
puts "=" * 70

parsed_events.sort_by { |e| -(e[:timestamp] || 0) }.first(10).each do |event|
  puts
  time_str = "#{format_time(event[:timestamp])} (#{relative_time(event[:timestamp])})"
  type_indicator = event[:type] == 'error' ? 'ERROR'.red : 'WARN'.yellow

  puts "#{time_str} #{type_indicator}"
  puts "  Message: #{event[:message].strip[0..80]}"
  puts "  File: #{event[:file_short]}"
  puts "  URL: #{short_url(event[:url])}" if event[:url]
  puts "  User: #{event[:user]}" if event[:user] && event[:user] != 'Guest User'
  puts "  Build: #{event[:build_id_short]}"

  if options[:verbose] && event[:callstack] && !event[:callstack].empty?
    e2_frames = event[:callstack].select { |f| f.include?('/var/everything/') }.last(5)
    unless e2_frames.empty?
      puts "  Callstack:"
      e2_frames.each { |f| puts "    - #{extract_file_short(f)}" }
    end
  end
end

# Show actionable recommendations
puts
puts "=" * 70
puts "RECOMMENDATIONS".bold
puts "=" * 70
puts

# Count actionable vs non-actionable
e2_errors = parsed_events.count { |e| e[:is_e2_code] }
lib_errors = parsed_events.length - e2_errors
error_count = parsed_events.count { |e| e[:type] == 'error' }
warning_count = parsed_events.length - error_count

if error_count > 0
  puts "#{error_count} FATAL ERRORS detected - these should be investigated first!".red
end

if e2_errors > 0
  puts "#{e2_errors} errors in E2 code - these are actionable".cyan
end

if lib_errors > 0
  puts "#{lib_errors} errors in libraries - may need dependency updates".dim
end

# Specific recommendations based on patterns
sql_injection = parsed_events.count { |e| e[:category] == :sql_injection }
if sql_injection > 5
  puts
  puts "HIGH: #{sql_injection} potential SQL injection attempts detected".red
  puts "  Consider adding input validation or rate limiting"
end

null_refs = parsed_events.count { |e| e[:category] == :null_reference }
if null_refs > 5
  puts
  puts "MEDIUM: #{null_refs} null reference errors".yellow
  puts "  Add defensive checks for undefined values"
end

encoding = parsed_events.count { |e| e[:category] == :encoding }
if encoding > 0
  puts
  puts "LOW: #{encoding} encoding issues - may cause display problems".dim
end

puts
puts "Run with --verbose for full callstacks, --actionable for E2-only errors"
