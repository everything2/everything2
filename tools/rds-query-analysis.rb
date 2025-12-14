#!/usr/bin/env ruby
# frozen_string_literal: true

# RDS Query Analysis Tool
#
# Analyzes MySQL Performance Schema to identify queries causing memory pressure.
# Examines long-running queries, high memory consumers, and temporary table usage.
#
# Usage:
#   ./tools/rds-query-analysis.rb                    # Analyze current queries
#   ./tools/rds-query-analysis.rb --slow-queries     # Show slow query log summary
#   ./tools/rds-query-analysis.rb --temp-tables      # Queries creating temp tables
#   ./tools/rds-query-analysis.rb --full             # All analysis
#
# Prerequisites:
#   - Access to RDS instance (via bastion or direct connection)
#   - Performance Schema enabled (default on RDS)

require 'json'
require 'optparse'

DB_ENDPOINT = 'everything2vpc.cgd4y1jfydlq.us-west-2.rds.amazonaws.com'
DB_USER = 'everyuser'
DB_NAME = 'everything'

options = {
  slow_queries: false,
  temp_tables: false,
  full: false,
  limit: 20
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-s", "--slow-queries", "Analyze slow query log") do
    options[:slow_queries] = true
  end

  opts.on("-t", "--temp-tables", "Find queries creating temp tables") do
    options[:temp_tables] = true
  end

  opts.on("-f", "--full", "Full analysis (all checks)") do
    options[:full] = true
  end

  opts.on("-l", "--limit N", Integer, "Limit results (default: 20)") do |n|
    options[:limit] = n
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "This tool analyzes MySQL queries to identify memory pressure causes."
    puts
    puts "Analysis includes:"
    puts "  - Long-running queries (> 1 second)"
    puts "  - Queries with high temporary table usage"
    puts "  - Slow query log analysis"
    puts "  - Memory-intensive operations"
    puts
    puts "Example:"
    puts "  #{$PROGRAM_NAME} --full         # Run all checks"
    puts "  #{$PROGRAM_NAME} --temp-tables  # Focus on temp table usage"
    exit
  end
end.parse!

def mysql_query(query)
  # Run query via docker exec to local dev database (can be adapted for RDS)
  cmd = [
    'docker', 'exec', 'e2devdb',
    'mysql', '-u', 'root', '-pblah', '-e', query, 'everything'
  ]

  output = `#{cmd.join(' ')}`.strip

  unless $?.success?
    STDERR.puts "MySQL query failed: #{query}"
    return nil
  end

  output
end

def parse_table(output)
  return [] if output.nil? || output.empty?

  lines = output.split("\n")
  return [] if lines.length < 2

  headers = lines[0].split("\t")
  rows = []

  lines[1..-1].each do |line|
    values = line.split("\t")
    row = {}
    headers.each_with_index do |header, i|
      row[header] = values[i]
    end
    rows << row
  end

  rows
end

def format_time(seconds)
  return "0s" if seconds.nil? || seconds.to_f == 0

  s = seconds.to_f
  if s < 1
    "#{(s * 1000).round(0)}ms"
  elsif s < 60
    "#{s.round(2)}s"
  elsif s < 3600
    "#{(s / 60).round(1)}m"
  else
    "#{(s / 3600).round(1)}h"
  end
end

def format_bytes(bytes)
  return "0 B" if bytes.nil? || bytes.to_i == 0

  b = bytes.to_i
  units = ['B', 'KB', 'MB', 'GB', 'TB']
  exp = (Math.log(b) / Math.log(1024)).to_i
  exp = units.length - 1 if exp >= units.length

  "#{(b.to_f / (1024**exp)).round(2)} #{units[exp]}"
end

def analyze_current_queries(options)
  puts "Current Active Queries"
  puts "=" * 80
  puts

  # Find currently running queries
  query = <<-SQL
    SELECT
      pl.ID,
      pl.USER,
      pl.DB,
      pl.COMMAND,
      pl.TIME,
      pl.STATE,
      SUBSTRING(pl.INFO, 1, 100) as QUERY
    FROM information_schema.PROCESSLIST pl
    WHERE pl.COMMAND != 'Sleep'
      AND pl.ID != CONNECTION_ID()
    ORDER BY pl.TIME DESC
    LIMIT #{options[:limit]};
  SQL

  result = mysql_query(query)
  rows = parse_table(result)

  if rows.empty?
    puts "No active queries currently running"
  else
    puts "Found #{rows.length} active queries:\n\n"

    rows.each do |row|
      puts "ID: #{row['ID']}"
      puts "  User: #{row['USER']}"
      puts "  Database: #{row['DB']}"
      puts "  Runtime: #{format_time(row['TIME'])}"
      puts "  State: #{row['STATE']}"
      puts "  Query: #{row['QUERY']}"
      puts
    end

    # Highlight long-running queries
    long_running = rows.select { |r| r['TIME'].to_i > 1 }
    if long_running.any?
      puts "⚠️  #{long_running.length} long-running queries (> 1s)"
      puts "    These may be causing memory pressure"
    end
  end

  puts
end

def analyze_temp_tables(options)
  puts "Queries Creating Temporary Tables"
  puts "=" * 80
  puts

  # Check for queries creating temp tables (using slow query log digest)
  query = <<-SQL
    SELECT
      DIGEST_TEXT,
      COUNT_STAR as executions,
      SUM_CREATED_TMP_DISK_TABLES as disk_tmp_tables,
      SUM_CREATED_TMP_TABLES as tmp_tables,
      ROUND(AVG_TIMER_WAIT / 1000000000000, 2) as avg_time_sec,
      ROUND(SUM_TIMER_WAIT / 1000000000000, 2) as total_time_sec
    FROM performance_schema.events_statements_summary_by_digest
    WHERE SUM_CREATED_TMP_TABLES > 0
    ORDER BY SUM_CREATED_TMP_DISK_TABLES DESC, SUM_CREATED_TMP_TABLES DESC
    LIMIT #{options[:limit]};
  SQL

  result = mysql_query(query)
  rows = parse_table(result)

  if rows.empty?
    puts "No queries with temporary tables found"
  else
    puts "Found #{rows.length} queries creating temporary tables:\n\n"

    rows.each_with_index do |row, i|
      disk_tmp = row['disk_tmp_tables'].to_i
      total_tmp = row['tmp_tables'].to_i

      puts "#{i + 1}. Query Digest:"
      puts "   Executions: #{row['executions']}"
      puts "   Temp Tables: #{total_tmp} (#{disk_tmp} on disk)"
      puts "   Avg Time: #{row['avg_time_sec']}s"
      puts "   Total Time: #{row['total_time_sec']}s"
      puts "   Query: #{row['DIGEST_TEXT'][0..150]}..."
      puts

      if disk_tmp > 0
        puts "   ⚠️  Creating disk-based temp tables - this causes memory/swap pressure!"
        puts
      end
    end
  end

  puts
end

def analyze_memory_usage(options)
  puts "Memory Usage by Statement"
  puts "=" * 80
  puts

  # Get memory usage from performance schema (MySQL 8.0+)
  query = <<-SQL
    SELECT
      event_name,
      current_count_used as count_used,
      current_number_of_bytes_used as bytes_used,
      high_count_used,
      high_number_of_bytes_used as high_bytes_used
    FROM performance_schema.memory_summary_global_by_event_name
    WHERE current_number_of_bytes_used > 0
    ORDER BY current_number_of_bytes_used DESC
    LIMIT #{options[:limit]};
  SQL

  result = mysql_query(query)
  rows = parse_table(result)

  if rows.empty?
    puts "No memory usage data available"
  else
    puts "Top #{rows.length} memory consumers:\n\n"

    total_bytes = rows.map { |r| r['bytes_used'].to_i }.sum

    rows.each_with_index do |row, i|
      bytes = row['bytes_used'].to_i
      high_bytes = row['high_bytes_used'].to_i
      pct = (bytes.to_f / total_bytes * 100).round(1)

      puts "#{i + 1}. #{row['event_name']}"
      puts "   Current: #{format_bytes(bytes)} (#{pct}% of total)"
      puts "   Peak: #{format_bytes(high_bytes)}"
      puts "   Allocations: #{row['count_used']} (peak: #{row['high_count_used']})"
      puts
    end

    puts "Total tracked memory usage: #{format_bytes(total_bytes)}"
  end

  puts
end

def analyze_innodb_buffer_pool(options)
  puts "InnoDB Buffer Pool Status"
  puts "=" * 80
  puts

  query = <<-SQL
    SHOW STATUS LIKE 'Innodb_buffer_pool%';
  SQL

  result = mysql_query(query)
  rows = parse_table(result)

  if rows.empty?
    puts "No InnoDB buffer pool data available"
  else
    # Parse key metrics
    metrics = {}
    rows.each { |r| metrics[r['Variable_name']] = r['Value'].to_i }

    pool_size = metrics['Innodb_buffer_pool_pages_total'] * 16 * 1024  # pages * 16KB
    pool_data = metrics['Innodb_buffer_pool_pages_data'] * 16 * 1024
    pool_free = metrics['Innodb_buffer_pool_pages_free'] * 16 * 1024
    pool_dirty = metrics['Innodb_buffer_pool_pages_dirty'] * 16 * 1024

    reads = metrics['Innodb_buffer_pool_reads']
    read_requests = metrics['Innodb_buffer_pool_read_requests']
    hit_rate = read_requests > 0 ? ((read_requests - reads).to_f / read_requests * 100).round(2) : 0

    puts "Buffer Pool Size: #{format_bytes(pool_size)}"
    puts "Data Pages: #{format_bytes(pool_data)} (#{(pool_data.to_f / pool_size * 100).round(1)}%)"
    puts "Free Pages: #{format_bytes(pool_free)} (#{(pool_free.to_f / pool_size * 100).round(1)}%)"
    puts "Dirty Pages: #{format_bytes(pool_dirty)} (#{(pool_dirty.to_f / pool_size * 100).round(1)}%)"
    puts
    puts "Read Requests: #{read_requests.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "Disk Reads: #{reads.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "Hit Rate: #{hit_rate}%"
    puts

    if hit_rate < 99
      puts "⚠️  Low buffer pool hit rate - consider increasing innodb_buffer_pool_size"
    elsif pool_free.to_f / pool_size < 0.05
      puts "⚠️  Very little free buffer pool space - may cause evictions"
    else
      puts "✓ Buffer pool is healthy"
    end
  end

  puts
end

def analyze_table_sizes(options)
  puts "Largest Tables (by data + index size)"
  puts "=" * 80
  puts

  query = <<-SQL
    SELECT
      table_name,
      ROUND(((data_length + index_length) / 1024 / 1024), 2) as size_mb,
      ROUND((data_length / 1024 / 1024), 2) as data_mb,
      ROUND((index_length / 1024 / 1024), 2) as index_mb,
      table_rows
    FROM information_schema.TABLES
    WHERE table_schema = 'everything'
    ORDER BY (data_length + index_length) DESC
    LIMIT #{options[:limit]};
  SQL

  result = mysql_query(query)
  rows = parse_table(result)

  if rows.empty?
    puts "No table data available"
  else
    puts "Top #{rows.length} largest tables:\n\n"

    rows.each_with_index do |row, i|
      puts "#{i + 1}. #{row['table_name']}"
      puts "   Total Size: #{row['size_mb']} MB"
      puts "   Data: #{row['data_mb']} MB, Indexes: #{row['index_mb']} MB"
      puts "   Rows: #{row['table_rows'].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts
    end
  end

  puts
end

# Main execution
puts "MySQL Query Analysis Tool"
puts "=" * 80
puts "Target: Development database (e2devdb)"
puts "Note: For production RDS analysis, configure SSH tunnel or use RDS proxy"
puts "=" * 80
puts

if options[:full]
  options[:slow_queries] = true
  options[:temp_tables] = true
end

# Always show current queries
analyze_current_queries(options)

# Show temp table analysis if requested
if options[:temp_tables] || options[:full]
  analyze_temp_tables(options)
end

# Show memory analysis
analyze_memory_usage(options)

# Show InnoDB buffer pool status
analyze_innodb_buffer_pool(options)

# Show table sizes (helps understand memory pressure)
analyze_table_sizes(options)

puts "=" * 80
puts "Analysis complete"
puts
puts "To reduce memory pressure:"
puts "  1. Optimize queries creating disk-based temp tables"
puts "  2. Add indexes to reduce full table scans"
puts "  3. Limit result sets with WHERE clauses"
puts "  4. Review buffer pool hit rate and adjust if needed"
puts
puts "For production RDS analysis:"
puts "  - Enable Performance Insights in RDS console"
puts "  - Review CloudWatch metrics for detailed query analysis"
puts "  - Use RDS Enhanced Monitoring for OS-level metrics"
