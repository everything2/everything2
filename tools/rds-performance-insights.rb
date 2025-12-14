#!/usr/bin/env ruby
# frozen_string_literal: true

# RDS Performance Insights Analysis
#
# Uses AWS Performance Insights API to identify queries causing memory pressure.
# This is the proper way to analyze RDS queries without direct database access.
#
# Usage:
#   ./tools/rds-performance-insights.rb                    # Last hour
#   ./tools/rds-performance-insights.rb --hours 24         # Last 24 hours
#   ./tools/rds-performance-insights.rb --top-sql          # Top SQL by load
#
# Prerequisites:
#   - Performance Insights enabled on RDS (already enabled)
#   - AWS CLI configured with appropriate credentials

require 'json'
require 'optparse'
require 'open3'
require 'time'

REGION = 'us-west-2'
DB_INSTANCE = 'everything2vpc'
DB_RESOURCE_ID = nil  # Will be looked up

options = {
  hours: 1,
  top_sql: false,
  wait_events: false,
  profile: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("--hours N", Integer, "Hours of data to analyze (default: 1)") do |n|
    options[:hours] = n
  end

  opts.on("--top-sql", "Show top SQL statements by load") do
    options[:top_sql] = true
  end

  opts.on("--wait-events", "Show wait events") do
    options[:wait_events] = true
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "This tool uses RDS Performance Insights to identify query patterns"
    puts "that may be causing memory pressure and swap usage."
    puts
    puts "Example:"
    puts "  #{$PROGRAM_NAME} --hours 24 --top-sql"
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

def get_db_resource_id(options)
  result = run_aws(options, "rds", "describe-db-instances",
                   "--db-instance-identifier", DB_INSTANCE)

  return nil unless result && result['DBInstances']&.any?

  result['DBInstances'].first['DbiResourceId']
end

def get_performance_insights_metrics(options, resource_id, hours)
  end_time = Time.now
  start_time = end_time - (hours * 3600)

  # Get top dimensions by load
  result = run_aws(options, "pi", "describe-dimension-keys",
                   "--service-type", "RDS",
                   "--identifier", resource_id,
                   "--start-time", start_time.utc.iso8601,
                   "--end-time", end_time.utc.iso8601,
                   "--metric", "db.load.avg",
                   "--group-by", '{"Group":"db.sql"}',
                   "--period-in-seconds", "3600")

  result
end

def get_sql_text(options, resource_id, sql_id)
  result = run_aws(options, "pi", "get-dimension-key-details",
                   "--service-type", "RDS",
                   "--identifier", resource_id,
                   "--group", "db.sql",
                   "--group-identifier", sql_id)

  return nil unless result && result['Dimensions']

  result['Dimensions']
end

puts "RDS Performance Insights Analysis"
puts "=" * 80
puts "Database: #{DB_INSTANCE}"
puts "Region: #{REGION}"
puts "Period: Last #{options[:hours]} hour(s)"
puts "=" * 80
puts

# Get DB Resource ID
print "Looking up DB Resource ID... "
resource_id = get_db_resource_id(options)

unless resource_id
  STDERR.puts "ERROR"
  STDERR.puts "Could not find DB instance: #{DB_INSTANCE}"
  exit 1
end

puts resource_id
puts

# Get Performance Insights data
puts "Fetching Performance Insights metrics..."
puts

metrics = get_performance_insights_metrics(options, resource_id, options[:hours])

unless metrics && metrics['Keys']
  STDERR.puts "No Performance Insights data available"
  STDERR.puts "Make sure Performance Insights is enabled on the RDS instance"
  exit 1
end

puts "Top SQL Statements by Database Load"
puts "=" * 80
puts

keys = metrics['Keys'].sort_by { |k| -(k['Total'] || 0) }

if keys.empty?
  puts "No SQL statements found in the selected time period"
else
  puts "Found #{keys.length} SQL statements\n\n"

  keys.first([20, keys.length].min).each_with_index do |key, i|
    sql_id = key['Dimensions']['db.sql.id']
    load_avg = key['Total']

    puts "#{i + 1}. SQL ID: #{sql_id}"
    puts "   Average DB Load: #{load_avg.round(4)}"

    # Get SQL text if requested
    if options[:top_sql]
      sql_details = get_sql_text(options, resource_id, sql_id)
      if sql_details
        statement = sql_details.find { |d| d['Dimension'] == 'db.sql.statement' }
        if statement
          sql_text = statement['Value']
          puts "   SQL: #{sql_text[0..200]}#{sql_text.length > 200 ? '...' : ''}"
        end
      end
    end

    puts
  end
end

puts
puts "=" * 80
puts "Recommendations:"
puts
puts "1. **Check CloudWatch Metrics for these specific queries:**"
puts "   - Queries with high DB Load are candidates for optimization"
puts "   - Look for patterns in query execution times"
puts
puts "2. **For detailed query analysis:**"
puts "   - View Performance Insights dashboard in AWS Console"
puts "   - https://console.aws.amazon.com/rds/home?region=#{REGION}#performance-insights-v20206:"
puts "     dbInstanceIdentifier=#{DB_INSTANCE}"
puts
puts "3. **Common causes of memory pressure:**"
puts "   - Large result sets without LIMIT clauses"
puts "   - Queries creating temporary tables on disk"
puts "   - Missing indexes causing full table scans"
puts "   - Suboptimal JOIN operations"
puts "   - Large GROUP BY operations"
puts
puts "4. **To analyze swap usage correlation:**"
puts "   - Compare these query times with CloudWatch SwapUsage metric"
puts "   - Look for queries running when swap spikes occur"
puts "   - Review slow query log for queries > 3 seconds"
puts
puts "5. **RDS-specific optimizations:**"
puts "   - Review parameter group settings"
puts "   - Check for long-running transactions"
puts "   - Monitor connection pool usage"
