#!/usr/bin/env ruby
#
# ELB Log Bot and Spike Analysis Tool
# Analyzes ELB logs to identify bots, scrapers, and activity spikes
#
# Usage:
#   ./tools/bot-spike-analysis.rb [options]
#
# Options:
#   --min-requests N    Only show IPs with at least N requests (default: 100)
#   --time-window N     Time window in minutes for spike detection (default: 5)
#   --top N             Show top N results (default: 50)
#   --ip IP             Filter to specific IP address
#   --help              Show this help
#
# Examples:
#   ./tools/bot-spike-analysis.rb
#   ./tools/bot-spike-analysis.rb --min-requests 1000
#   ./tools/bot-spike-analysis.rb --ip 1.2.3.4
#

require 'find'
require 'zlib'
require 'optparse'
require 'time'

# Parse command-line options
options = {
  min_requests: 100,
  time_window: 5,
  top: 50,
  ip: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: bot-spike-analysis.rb [options]"

  opts.on("--min-requests N", Integer, "Minimum requests to show (default: 100)") do |n|
    options[:min_requests] = n
  end

  opts.on("--time-window N", Integer, "Time window in minutes (default: 5)") do |n|
    options[:time_window] = n
  end

  opts.on("--top N", Integer, "Show top N results (default: 50)") do |n|
    options[:top] = n
  end

  opts.on("--ip IP", String, "Filter to specific IP address") do |ip|
    options[:ip] = ip
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# ELB log format regex
elb_regex = %r{(?<type>[^ ]*) (?<time>[^ ]*) (?<elb>[^ ]*) (?<client_ip>[^ ]*):(?<client_port>[0-9]*) (?<target_ip>[^ ]*)[:-]([0-9]*) (?<request_processing_time>[-.0-9]*) (?<target_processing_time>[-.0-9]*) (?<response_processing_time>[-.0-9]*) (?<elb_status_code>|[-0-9]*) (?<target_status_code>\-|[-0-9]*) (?<received_bytes>[-0-9]*) (?<sent_bytes>[-0-9]*) \"(?<request_verb>[^ ]*) (?<request_url>.*) (?<request_proto>- |[^ ]*)\" \"(?<user_agent>[^\"]*)\" (?<ssl_cipher>[A-Z0-9\-_]+) (?<ssl_protocol>[A-Za-z0-9.-]*) (?<target_group_arn>[^ ]*) \"(?<trace_id>[^\"]*)\" \"(?<domain_name>[^\"]*)\" \"(?<chosen_cert_arn>[^\"]*)\" (?<matched_rule_priority>[\-.0-9]*) (?<request_creation_time>[^ ]*) \"(?<actions_executed>[^\"]*)\" \"(?<redirect_url>[^\"]*)\" \"(?<lambda_error_reason>[^ ]*)\" \"(?<target_port_list>[^\\s]+?)\" \"(?<target_status_code_list>[^\\s]+)\" \"(?<classification>[^ ]*)\" \"(?<classification_reason>[^ ]*)\" ?(?<conn_trace_id>[^ ]*)?}

# Known bot patterns in user agents
bot_patterns = [
  /bot/i,
  /crawl/i,
  /spider/i,
  /scrape/i,
  /slurp/i,
  /scan/i,
  /check/i,
  /monitor/i,
  /index/i,
  /fetch/i,
  /google/i,
  /bing/i,
  /yandex/i,
  /baidu/i,
  /duckduck/i,
  /yahoo/i,
  /ask\.com/i,
  /aolbuild/i,
  /teoma/i,
  /exabot/i,
  /wget/i,
  /curl/i,
  /python/i,
  /perl/i,
  /java/i,
  /ruby/i,
  /go-http-client/i,
  /apache-httpclient/i,
  /okhttp/i
]

# Data structures
ip_stats = Hash.new do |h, k|
  h[k] = {
    count: 0,
    user_agents: Hash.new(0),
    paths: Hash.new(0),
    timestamps: [],
    status_codes: Hash.new(0),
    bytes_sent: 0,
    is_bot: false
  }
end

time_buckets = Hash.new { |h, k| h[k] = Hash.new(0) }
total_requests = 0
files_inspected = 0

puts "Analyzing ELB logs in current directory..."
puts "Min requests threshold: #{options[:min_requests]}"
puts "Time window: #{options[:time_window]} minutes"
puts

# Process all gzipped log files
Find.find('.').each do |file|
  next if FileTest.directory?(file)
  next unless file.match(/\.gz$/)

  files_inspected += 1
  print "Reading #{file}..."

  begin
    gz = Zlib::GzipReader.new(File.open(file))
    line_count = 0

    gz.each_line do |line|
      line_count += 1
      linedata = line.match(elb_regex)
      next unless linedata

      total_requests += 1
      client_ip = linedata[:client_ip]

      # Filter by IP if specified
      next if options[:ip] && client_ip != options[:ip]

      # Parse timestamp
      begin
        timestamp = Time.parse(linedata[:time])
      rescue
        next
      end

      # Update IP statistics
      ip_stats[client_ip][:count] += 1
      ip_stats[client_ip][:timestamps] << timestamp
      ip_stats[client_ip][:user_agents][linedata[:user_agent]] += 1
      ip_stats[client_ip][:status_codes][linedata[:target_status_code]] += 1

      # Extract path
      path = ''
      if pathdata = linedata[:request_url].match(%r{(?:https?://[^/]+)?/(?<path>[^ ?]*)})
        path = '/' + pathdata[:path]
      end
      ip_stats[client_ip][:paths][path] += 1

      # Track bytes
      bytes = linedata[:sent_bytes].to_i
      ip_stats[client_ip][:bytes_sent] += bytes if bytes > 0

      # Check if user agent matches bot pattern
      user_agent = linedata[:user_agent]
      if bot_patterns.any? { |pattern| user_agent.match(pattern) }
        ip_stats[client_ip][:is_bot] = true
      end

      # Track time buckets (for spike detection)
      bucket_time = timestamp.to_i / (options[:time_window] * 60) * (options[:time_window] * 60)
      time_buckets[bucket_time][client_ip] += 1
    end

    puts " #{line_count} lines"
  rescue => e
    puts " ERROR: #{e.message}"
  end
end

puts
puts "=" * 80
puts "ANALYSIS SUMMARY"
puts "=" * 80
puts "Files inspected: #{files_inspected}"
puts "Total requests: #{total_requests}"
puts "Unique IPs: #{ip_stats.keys.length}"
puts

# Filter IPs by minimum request threshold
filtered_ips = ip_stats.select { |ip, stats| stats[:count] >= options[:min_requests] }

if filtered_ips.empty?
  puts "No IPs found with >= #{options[:min_requests]} requests"
  puts "Try lowering --min-requests threshold"
  exit
end

puts "IPs with >= #{options[:min_requests]} requests: #{filtered_ips.keys.length}"
puts

# Analyze each IP for spike patterns
filtered_ips.each do |ip, stats|
  # Calculate request rate (requests per minute)
  if stats[:timestamps].length > 1
    time_span = (stats[:timestamps].max - stats[:timestamps].min) / 60.0
    time_span = 1 if time_span < 1
    stats[:requests_per_minute] = stats[:count] / time_span
  else
    stats[:requests_per_minute] = 0
  end

  # Calculate burst score (variance in request timing)
  if stats[:timestamps].length > 2
    intervals = []
    sorted_times = stats[:timestamps].sort
    sorted_times.each_cons(2) do |t1, t2|
      intervals << (t2 - t1)
    end
    avg_interval = intervals.sum / intervals.length.to_f
    variance = intervals.map { |i| (i - avg_interval) ** 2 }.sum / intervals.length.to_f
    stats[:burst_score] = Math.sqrt(variance)
  else
    stats[:burst_score] = 0
  end
end

# Sort by request count
sorted_by_count = filtered_ips.sort_by { |ip, stats| -stats[:count] }

puts "=" * 80
puts "TOP #{options[:top]} IPs BY REQUEST COUNT"
puts "=" * 80
puts "%-15s %10s %8s %6s %s" % ["IP", "Requests", "Req/min", "Bot?", "Top User Agent"]
puts "-" * 80

sorted_by_count.first(options[:top]).each do |ip, stats|
  top_ua = stats[:user_agents].max_by { |ua, count| count }
  ua_display = top_ua[0][0..60]
  ua_display += "..." if top_ua[0].length > 60

  printf "%-15s %10d %8.1f %6s %s\n",
    ip,
    stats[:count],
    stats[:requests_per_minute],
    stats[:is_bot] ? "YES" : "no",
    ua_display
end

puts
puts "=" * 80
puts "TOP #{options[:top]} IPs BY REQUEST RATE (requests/minute)"
puts "=" * 80
sorted_by_rate = filtered_ips.sort_by { |ip, stats| -stats[:requests_per_minute] }
puts "%-15s %10s %8s %10s %s" % ["IP", "Requests", "Req/min", "Burst", "Bot?"]
puts "-" * 80

sorted_by_rate.first(options[:top]).each do |ip, stats|
  printf "%-15s %10d %8.1f %10.1f %s\n",
    ip,
    stats[:count],
    stats[:requests_per_minute],
    stats[:burst_score],
    stats[:is_bot] ? "YES" : "no"
end

puts
puts "=" * 80
puts "KNOWN BOTS (User Agent Pattern Match)"
puts "=" * 80

bots = filtered_ips.select { |ip, stats| stats[:is_bot] }
if bots.empty?
  puts "No known bots detected"
else
  sorted_bots = bots.sort_by { |ip, stats| -stats[:count] }
  puts "%-15s %10s %8s %s" % ["IP", "Requests", "Req/min", "Top User Agent"]
  puts "-" * 80

  sorted_bots.first(options[:top]).each do |ip, stats|
    top_ua = stats[:user_agents].max_by { |ua, count| count }
    ua_display = top_ua[0][0..60]
    ua_display += "..." if top_ua[0].length > 60

    printf "%-15s %10d %8.1f %s\n",
      ip,
      stats[:count],
      stats[:requests_per_minute],
      ua_display
  end
end

puts
puts "=" * 80
puts "SUSPICIOUS PATTERNS (High rate, not identified as bot)"
puts "=" * 80

# Suspicious: high request rate but not matching bot patterns
suspicious = filtered_ips.select do |ip, stats|
  !stats[:is_bot] && stats[:requests_per_minute] > 5
end

if suspicious.empty?
  puts "No suspicious patterns detected"
else
  sorted_suspicious = suspicious.sort_by { |ip, stats| -stats[:requests_per_minute] }
  puts "%-15s %10s %8s %10s %s" % ["IP", "Requests", "Req/min", "Burst", "Top User Agent"]
  puts "-" * 80

  sorted_suspicious.first(options[:top]).each do |ip, stats|
    top_ua = stats[:user_agents].max_by { |ua, count| count }
    ua_display = top_ua[0][0..40]
    ua_display += "..." if top_ua[0].length > 40

    printf "%-15s %10d %8.1f %10.1f %s\n",
      ip,
      stats[:count],
      stats[:requests_per_minute],
      stats[:burst_score],
      ua_display
  end
end

puts
puts "=" * 80
puts "TIME-BASED SPIKE ANALYSIS"
puts "=" * 80
puts "Time window: #{options[:time_window]} minutes"
puts

# Find time buckets with unusual activity
bucket_stats = time_buckets.map do |bucket_time, ip_counts|
  {
    time: Time.at(bucket_time),
    total_requests: ip_counts.values.sum,
    unique_ips: ip_counts.keys.length,
    top_ip: ip_counts.max_by { |ip, count| count }
  }
end

sorted_buckets = bucket_stats.sort_by { |b| -b[:total_requests] }

puts "Top #{[20, sorted_buckets.length].min} busiest time windows:"
puts "%-20s %10s %8s %15s %10s" % ["Time", "Requests", "Uniq IPs", "Top IP", "Top Count"]
puts "-" * 80

sorted_buckets.first(20).each do |bucket|
  printf "%-20s %10d %8d %15s %10d\n",
    bucket[:time].strftime("%Y-%m-%d %H:%M"),
    bucket[:total_requests],
    bucket[:unique_ips],
    bucket[:top_ip][0],
    bucket[:top_ip][1]
end

# Detailed analysis if single IP specified
if options[:ip] && ip_stats[options[:ip]]
  stats = ip_stats[options[:ip]]
  puts
  puts "=" * 80
  puts "DETAILED ANALYSIS FOR IP: #{options[:ip]}"
  puts "=" * 80
  puts "Total requests: #{stats[:count]}"
  puts "Requests per minute: %.1f" % stats[:requests_per_minute]
  puts "Burst score: %.1f" % stats[:burst_score]
  puts "Identified as bot: #{stats[:is_bot] ? 'YES' : 'NO'}"
  puts "Total bytes sent: #{stats[:bytes_sent]}"
  puts

  puts "User Agents:"
  stats[:user_agents].sort_by { |ua, count| -count }.first(10).each do |ua, count|
    puts "  #{count}: #{ua}"
  end

  puts
  puts "Top Paths:"
  stats[:paths].sort_by { |path, count| -count }.first(20).each do |path, count|
    puts "  #{count}: #{path}"
  end

  puts
  puts "Status Codes:"
  stats[:status_codes].sort_by { |code, count| -count }.each do |code, count|
    puts "  #{code}: #{count}"
  end

  puts
  puts "Request Timeline (first 50):"
  stats[:timestamps].sort.first(50).each do |t|
    puts "  #{t.strftime('%Y-%m-%d %H:%M:%S')}"
  end
end

puts
puts "=" * 80
puts "ANALYSIS COMPLETE"
puts "=" * 80
