#!/usr/bin/env ruby
# CloudWatch Log Storage Analysis
# Shows which log groups and streams are consuming the most storage
#
# Usage: ./tools/cloudwatch-storage-analysis.rb [--region us-east-1] [--top N]

require 'json'
require 'optparse'

options = {
  region: 'us-east-1',
  top: 20,
  profile: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-r", "--region REGION", "AWS region (default: us-east-1)") do |r|
    options[:region] = r
  end

  opts.on("-t", "--top N", Integer, "Show top N results (default: 20)") do |n|
    options[:top] = n
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

def format_bytes(bytes)
  return "0 B" if bytes.nil? || bytes == 0

  units = ['B', 'KB', 'MB', 'GB', 'TB']
  exp = (Math.log(bytes) / Math.log(1024)).to_i
  exp = units.length - 1 if exp >= units.length

  "%.2f %s" % [bytes.to_f / (1024 ** exp), units[exp]]
end

def format_time(timestamp_ms)
  return "N/A" if timestamp_ms.nil? || timestamp_ms == 0
  Time.at(timestamp_ms / 1000).strftime("%Y-%m-%d %H:%M")
end

def aws_cmd(options)
  cmd = "aws"
  cmd += " --profile #{options[:profile]}" if options[:profile]
  cmd += " --region #{options[:region]}"
  cmd
end

puts "CloudWatch Log Storage Analysis"
puts "=" * 60
puts "Region: #{options[:region]}"
puts "Fetching log groups..."
puts

# Get all log groups with their stored bytes
log_groups_cmd = "#{aws_cmd(options)} logs describe-log-groups --output json"
log_groups_json = `#{log_groups_cmd} 2>&1`

unless $?.success?
  puts "Error fetching log groups:"
  puts log_groups_json
  exit 1
end

log_groups_data = JSON.parse(log_groups_json)
log_groups = log_groups_data['logGroups'] || []

if log_groups.empty?
  puts "No log groups found in region #{options[:region]}"
  exit 0
end

# Sort by stored bytes descending
log_groups.sort_by! { |g| -(g['storedBytes'] || 0) }

total_bytes = log_groups.sum { |g| g['storedBytes'] || 0 }

puts "LOG GROUPS BY SIZE (Total: #{format_bytes(total_bytes)})"
puts "-" * 60

log_groups.first(options[:top]).each_with_index do |group, i|
  name = group['logGroupName']
  bytes = group['storedBytes'] || 0
  retention = group['retentionInDays'] || 'Never'
  pct = total_bytes > 0 ? (bytes.to_f / total_bytes * 100) : 0

  puts
  puts "#{i + 1}. #{name}"
  puts "   Size: #{format_bytes(bytes)} (#{pct.round(1)}%)"
  puts "   Retention: #{retention == 'Never' ? 'Never expires' : "#{retention} days"}"
end

puts
puts "=" * 60
puts "DETAILED STREAM ANALYSIS FOR TOP LOG GROUPS"
puts "=" * 60

# Analyze streams for top 5 log groups
log_groups.first(5).each do |group|
  group_name = group['logGroupName']
  group_bytes = group['storedBytes'] || 0

  next if group_bytes == 0

  puts
  puts "Log Group: #{group_name}"
  puts "Total Size: #{format_bytes(group_bytes)}"
  puts "-" * 50

  # Get log streams for this group, ordered by last event time
  streams_cmd = "#{aws_cmd(options)} logs describe-log-streams " \
                "--log-group-name '#{group_name}' " \
                "--order-by LastEventTime --descending " \
                "--limit 50 --output json"

  streams_json = `#{streams_cmd} 2>&1`

  unless $?.success?
    puts "  Error fetching streams: #{streams_json}"
    next
  end

  streams_data = JSON.parse(streams_json)
  streams = streams_data['logStreams'] || []

  if streams.empty?
    puts "  No streams found"
    next
  end

  # Sort by stored bytes
  streams.sort_by! { |s| -(s['storedBytes'] || 0) }

  puts "  Top streams by size:"
  streams.first(10).each_with_index do |stream, i|
    name = stream['logStreamName']
    bytes = stream['storedBytes'] || 0
    last_event = stream['lastEventTimestamp']
    first_event = stream['firstEventTimestamp']

    # Truncate long stream names
    display_name = name.length > 50 ? "#{name[0..47]}..." : name

    puts
    puts "  #{i + 1}. #{display_name}"
    puts "     Size: #{format_bytes(bytes)}"
    puts "     First event: #{format_time(first_event)}"
    puts "     Last event: #{format_time(last_event)}"
  end

  # Show streams with no recent activity (potential cleanup candidates)
  one_week_ago = (Time.now.to_i - 7 * 24 * 3600) * 1000
  stale_streams = streams.select { |s| (s['lastEventTimestamp'] || 0) < one_week_ago && (s['storedBytes'] || 0) > 0 }

  if stale_streams.any?
    stale_bytes = stale_streams.sum { |s| s['storedBytes'] || 0 }
    puts
    puts "  Stale streams (no events in 7+ days): #{stale_streams.length}"
    puts "  Stale stream storage: #{format_bytes(stale_bytes)}"
  end
end

puts
puts "=" * 60
puts "RECOMMENDATIONS"
puts "=" * 60
puts

# Find groups without retention
no_retention = log_groups.select { |g| g['retentionInDays'].nil? }
if no_retention.any?
  no_retention_bytes = no_retention.sum { |g| g['storedBytes'] || 0 }
  puts "1. LOG GROUPS WITHOUT RETENTION POLICY"
  puts "   #{no_retention.length} log groups have no retention policy (never expire)"
  puts "   Total storage: #{format_bytes(no_retention_bytes)}"
  puts
  no_retention.first(10).each do |g|
    puts "   - #{g['logGroupName']} (#{format_bytes(g['storedBytes'] || 0)})"
  end
  puts
  puts "   To set 30-day retention:"
  puts "   aws logs put-retention-policy --log-group-name LOG_GROUP --retention-in-days 30"
  puts
end

# Find groups with long retention
long_retention = log_groups.select { |g| (g['retentionInDays'] || 0) > 90 }
if long_retention.any?
  puts "2. LOG GROUPS WITH LONG RETENTION (>90 days)"
  long_retention.first(10).each do |g|
    puts "   - #{g['logGroupName']}: #{g['retentionInDays']} days (#{format_bytes(g['storedBytes'] || 0)})"
  end
  puts
end

puts "3. QUICK CLEANUP COMMANDS"
puts
puts "   # Delete empty log streams older than 7 days:"
puts "   aws logs describe-log-streams --log-group-name LOG_GROUP \\"
puts "     --query 'logStreams[?storedBytes==`0`].logStreamName' --output text | \\"
puts "     xargs -I {} aws logs delete-log-stream --log-group-name LOG_GROUP --log-stream-name {}"
puts
puts "   # Set retention on all log groups to 30 days:"
puts "   aws logs describe-log-groups --query 'logGroups[?retentionInDays==null].logGroupName' --output text | \\"
puts "     xargs -I {} aws logs put-retention-policy --log-group-name {} --retention-in-days 30"
puts
