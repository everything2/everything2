#!/usr/bin/env ruby
#
# IPv6 Connection Analysis for ALB Logs
# Analyzes ELB access logs to show IPv4 vs IPv6 connection ratios
#
# Usage:
#   ./tools/ipv6-analysis.rb                    # Analyze logs in ../e2-loganalysis
#   ./tools/ipv6-analysis.rb /path/to/logs      # Analyze logs in specified directory
#
# The script looks for the client IP field in ALB access logs and categorizes
# connections as IPv4 or IPv6.

require 'zlib'
require 'time'

log_dir = ARGV[0] || '../e2-loganalysis'

unless Dir.exist?(log_dir)
  puts "Error: Log directory not found: #{log_dir}"
  puts "Run ./tools/download-elb-logs.sh #{log_dir} first"
  exit 1
end

# Find all .gz log files
log_files = Dir.glob("#{log_dir}/**/*.gz").sort

if log_files.empty?
  puts "No .gz log files found in #{log_dir}"
  exit 1
end

puts "=" * 60
puts "IPv6 Connection Analysis for ALB"
puts "=" * 60
puts "Analyzing #{log_files.length} log files..."
puts

ipv4_count = 0
ipv6_count = 0
ipv6_addresses = Hash.new(0)
hourly_stats = Hash.new { |h, k| h[k] = { ipv4: 0, ipv6: 0 } }

# ALB log format: client:port is field 3 (0-indexed: field 2)
# Format: type timestamp elb client:port target:port ...

log_files.each do |file|
  begin
    Zlib::GzipReader.open(file) do |gz|
      gz.each_line do |line|
        fields = line.split(' ')
        next if fields.length < 3

        # Extract timestamp (field 1) and client:port (field 2)
        timestamp = fields[1]
        client_port = fields[2]

        # Extract just the IP (remove port)
        client_ip = client_port.gsub(/:\d+$/, '')

        # Parse hour for time-based analysis
        begin
          hour = Time.parse(timestamp).strftime('%Y-%m-%d %H:00')
        rescue
          hour = 'unknown'
        end

        if client_ip.include?(':')
          # IPv6 address
          ipv6_count += 1
          ipv6_addresses[client_ip] += 1
          hourly_stats[hour][:ipv6] += 1
        else
          # IPv4 address
          ipv4_count += 1
          hourly_stats[hour][:ipv4] += 1
        end
      end
    end
  rescue => e
    STDERR.puts "Warning: Error reading #{file}: #{e.message}"
  end
end

total = ipv4_count + ipv6_count

puts "Overall Statistics"
puts "-" * 40
puts "Total connections: #{total}"
puts "IPv4 connections:  #{ipv4_count} (#{total > 0 ? (ipv4_count * 100.0 / total).round(2) : 0}%)"
puts "IPv6 connections:  #{ipv6_count} (#{total > 0 ? (ipv6_count * 100.0 / total).round(2) : 0}%)"
puts

if ipv6_count > 0
  puts "Unique IPv6 Addresses (Top 10)"
  puts "-" * 40
  ipv6_addresses.sort_by { |_, count| -count }.first(10).each do |ip, count|
    puts "  #{ip}: #{count} requests"
  end
  puts
end

if hourly_stats.length > 0
  puts "Hourly Breakdown (Last 24 hours)"
  puts "-" * 40
  puts "#{'Hour'.ljust(20)} #{'IPv4'.rjust(10)} #{'IPv6'.rjust(10)} #{'IPv6 %'.rjust(10)}"

  hourly_stats.keys.sort.last(24).each do |hour|
    stats = hourly_stats[hour]
    total_hour = stats[:ipv4] + stats[:ipv6]
    ipv6_pct = total_hour > 0 ? (stats[:ipv6] * 100.0 / total_hour).round(1) : 0
    puts "#{hour.ljust(20)} #{stats[:ipv4].to_s.rjust(10)} #{stats[:ipv6].to_s.rjust(10)} #{(ipv6_pct.to_s + '%').rjust(10)}"
  end
end

puts
puts "=" * 60
if ipv6_count == 0
  puts "No IPv6 connections detected yet."
  puts "After enabling dualstack, allow time for:"
  puts "  1. CloudFormation deployment to complete"
  puts "  2. ALB to get IPv6 addresses"
  puts "  3. CloudFront to start using IPv6 connections"
  puts "  4. New log files to be written to S3"
else
  puts "IPv6 connections detected! CloudFront is using IPv6."
  if ipv6_count * 100.0 / total > 50
    puts "Majority of traffic is IPv6 - safe to consider dualstack-without-public-ipv4"
  end
end
puts "=" * 60
