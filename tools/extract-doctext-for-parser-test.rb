#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract doctext from RDS snapshot export for parser testing
# Filters out:
# - System nodes (present in nodepack/)
# - Code blocks ([% %] from legacy codehome)
# Outputs JSON for React parser testing

require 'json'
require 'set'
require 'zlib'

# Check for required gem
begin
  require 'parquet'
rescue LoadError
  STDERR.puts "Error: parquet gem not installed"
  STDERR.puts "Install with: gem install parquet"
  exit 1
end

EXPORT_DIR = "../e2-doctext/e2-writeup-export-20251214-141742/everything/everything.document/1"
NODEPACK_DIR = "nodepack"
OUTPUT_FILE = "../e2-doctext/doctext-samples.json"
MAX_SAMPLES = 1000 # Limit output size

def get_system_node_ids
  puts "Loading system node IDs from nodepack..."
  system_nodes = Set.new

  Dir.glob("#{NODEPACK_DIR}/**/*.xml").each do |file|
    content = File.read(file)
    if content =~ /<node_id>(\d+)<\/node_id>/
      system_nodes.add($1.to_i)
    end
  end

  puts "  Found #{system_nodes.size} system nodes to exclude"
  system_nodes
end

def contains_code_block?(doctext)
  return false if doctext.nil?
  # Check for [% %] Mason2/codehome blocks
  doctext.include?('[%') && doctext.include?('%]')
end

def process_parquet_files(system_nodes)
  puts "Processing parquet files from #{EXPORT_DIR}..."

  samples = []
  total_processed = 0
  excluded_system = 0
  excluded_code = 0

  Dir.glob("#{EXPORT_DIR}/*.parquet").sort.each do |parquet_file|
    break if samples.size >= MAX_SAMPLES

    puts "  Reading #{File.basename(parquet_file)}..."

    begin
      # Read parquet file
      table = Parquet.read(parquet_file)

      # Process each row
      table.each do |row|
        break if samples.size >= MAX_SAMPLES

        total_processed += 1

        document_id = row['document_id']
        doctext = row['doctext']

        # Skip if nil
        next if document_id.nil? || doctext.nil? || doctext.empty?

        # Skip system nodes (document_id == node_id for documents)
        if system_nodes.include?(document_id)
          excluded_system += 1
          next
        end

        # Skip if contains code blocks
        if contains_code_block?(doctext)
          excluded_code += 1
          next
        end

        # Add to samples
        samples << {
          document_id: document_id,
          doctext: doctext,
          length: doctext.length
        }

        # Progress indicator
        if total_processed % 10000 == 0
          puts "    Processed #{total_processed} rows, collected #{samples.size} samples..."
        end
      end
    rescue => e
      STDERR.puts "  Error reading #{parquet_file}: #{e.message}"
      next
    end
  end

  puts
  puts "Processing complete!"
  puts "  Total rows processed: #{total_processed}"
  puts "  Excluded (system nodes): #{excluded_system}"
  puts "  Excluded (code blocks): #{excluded_code}"
  puts "  Samples collected: #{samples.size}"

  samples
end

def write_output(samples)
  puts
  puts "Writing output to #{OUTPUT_FILE}..."

  # Sort by length to get diverse samples
  samples.sort_by! { |s| s[:length] }

  # Take samples from different length buckets for diversity
  output = {
    metadata: {
      generated_at: Time.now.iso8601,
      total_samples: samples.size,
      length_stats: {
        min: samples.map { |s| s[:length] }.min,
        max: samples.map { |s| s[:length] }.max,
        avg: (samples.map { |s| s[:length] }.sum / samples.size.to_f).round(2)
      }
    },
    samples: samples.map { |s| { id: s[:document_id], text: s[:doctext], length: s[:length] } }
  }

  File.write(OUTPUT_FILE, JSON.pretty_generate(output))
  puts "  Wrote #{samples.size} samples to #{OUTPUT_FILE}"
  puts "  File size: #{(File.size(OUTPUT_FILE) / 1024.0 / 1024.0).round(2)} MB"
end

# Main execution
puts "E2 Doctext Extraction for Parser Testing"
puts "=" * 80
puts

system_nodes = get_system_node_ids
samples = process_parquet_files(system_nodes)

if samples.empty?
  STDERR.puts "Error: No samples collected!"
  exit 1
end

write_output(samples)

puts
puts "Done! Use this file to test React-based HTML parser against server-side rendering."
puts "Sample usage:"
puts "  node tools/test-react-parser.js ../e2-doctext/doctext-samples.json"
