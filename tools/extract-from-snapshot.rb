#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract Writeup Content from RDS Snapshot
#
# Downloads an RDS snapshot export from S3 and extracts writeup content locally,
# avoiding the need to run memory-intensive extraction jobs in production.
#
# Usage:
#   ./tools/extract-from-snapshot.rb --list                    # List available snapshots
#   ./tools/extract-from-snapshot.rb --snapshot <id>           # Export specific snapshot
#   ./tools/extract-from-snapshot.rb --latest                  # Export latest automated snapshot
#   ./tools/extract-from-snapshot.rb --download <export-id>    # Download existing export
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - S3 bucket for snapshot exports (created automatically if needed)
#   - IAM permissions for RDS snapshot export

require 'json'
require 'optparse'
require 'open3'
require 'fileutils'
require 'time'

REGION = 'us-west-2'
DB_INSTANCE = 'everything2vpc'
EXPORT_BUCKET = 'e2-snapshot-exports'
OUTPUT_DIR = 'tmp/snapshot-data'

options = {
  list: false,
  latest: false,
  snapshot_id: nil,
  export_id: nil,
  download_only: nil,
  profile: nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("--list", "List available RDS snapshots") do
    options[:list] = true
  end

  opts.on("--latest", "Export latest automated snapshot") do
    options[:latest] = true
  end

  opts.on("--snapshot ID", "Export specific snapshot ID") do |id|
    options[:snapshot_id] = id
  end

  opts.on("--export ID", "Download specific export ID") do |id|
    options[:export_id] = id
  end

  opts.on("--download ID", "Download existing export (alias for --export)") do |id|
    options[:export_id] = id
  end

  opts.on("-p", "--profile PROFILE", "AWS profile to use") do |p|
    options[:profile] = p
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts
    puts "This tool exports RDS snapshots to S3 and downloads writeup data locally."
    puts
    puts "Workflow:"
    puts "  1. ./tools/extract-from-snapshot.rb --list"
    puts "  2. ./tools/extract-from-snapshot.rb --latest  (or --snapshot <id>)"
    puts "  3. Wait for export to complete (15-30 minutes)"
    puts "  4. Download and process data locally"
    puts
    puts "The export creates Parquet files in S3 that can be queried with DuckDB"
    puts "or converted to JSON for analysis."
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

def list_snapshots(options)
  puts "Listing RDS snapshots for #{DB_INSTANCE}..."
  puts

  result = run_aws(options, "rds", "describe-db-snapshots",
                   "--db-instance-identifier", DB_INSTANCE)

  unless result && result['DBSnapshots']
    STDERR.puts "Error: Could not list snapshots"
    exit 1
  end

  snapshots = result['DBSnapshots'].sort_by { |s| s['SnapshotCreateTime'] }.reverse

  if snapshots.empty?
    puts "No snapshots found for #{DB_INSTANCE}"
    return
  end

  puts "Found #{snapshots.length} snapshot(s):"
  puts

  snapshots.first(10).each do |snap|
    created = Time.parse(snap['SnapshotCreateTime']).strftime('%Y-%m-%d %H:%M:%S')
    type = snap['SnapshotType']
    status = snap['Status']
    size = snap['AllocatedStorage']

    puts "#{snap['DBSnapshotIdentifier']}"
    puts "  Created: #{created} (#{type})"
    puts "  Status: #{status}, Size: #{size} GB"
    puts
  end

  if snapshots.length > 10
    puts "(Showing 10 most recent, #{snapshots.length - 10} more available)"
  end
end

def get_latest_snapshot(options)
  result = run_aws(options, "rds", "describe-db-snapshots",
                   "--db-instance-identifier", DB_INSTANCE,
                   "--snapshot-type", "automated")

  unless result && result['DBSnapshots']
    STDERR.puts "Error: Could not list snapshots"
    exit 1
  end

  snapshots = result['DBSnapshots']
    .select { |s| s['Status'] == 'available' }
    .sort_by { |s| s['SnapshotCreateTime'] }
    .reverse

  if snapshots.empty?
    STDERR.puts "Error: No available automated snapshots found"
    exit 1
  end

  snapshots.first
end

def export_snapshot(options, snapshot_id)
  puts "Exporting snapshot: #{snapshot_id}"
  puts

  # Check if bucket exists, create if not
  ensure_export_bucket(options)

  # Generate export identifier
  export_id = "e2-writeup-export-#{Time.now.strftime('%Y%m%d-%H%M%S')}"

  # Get snapshot ARN
  result = run_aws(options, "rds", "describe-db-snapshots",
                   "--db-snapshot-identifier", snapshot_id)

  unless result && result['DBSnapshots']&.any?
    STDERR.puts "Error: Snapshot not found: #{snapshot_id}"
    exit 1
  end

  snapshot_arn = result['DBSnapshots'].first['DBSnapshotArn']

  puts "Starting export to S3..."
  puts "  Export ID: #{export_id}"
  puts "  Bucket: s3://#{EXPORT_BUCKET}/#{export_id}/"
  puts

  # Get or create KMS key for encryption
  kms_key_id = get_or_create_kms_key(options)

  # Export to S3 (only specific tables to reduce size)
  # node table: has node_id, title, type_nodetype, author_user, createtime
  # document table: has document_id (FK to node.node_id) and doctext (the actual writeup content)
  export_result = run_aws(options, "rds", "start-export-task",
                          "--export-task-identifier", export_id,
                          "--source-arn", snapshot_arn,
                          "--s3-bucket-name", EXPORT_BUCKET,
                          "--s3-prefix", export_id,
                          "--iam-role-arn", get_export_role_arn(options),
                          "--kms-key-id", kms_key_id,
                          "--export-only", "everything.node",
                          "--export-only", "everything.document")

  unless export_result
    STDERR.puts "Error: Failed to start export"
    exit 1
  end

  puts "Export started successfully!"
  puts
  puts "Monitor progress with:"
  puts "  aws rds describe-export-tasks --export-task-identifier #{export_id}"
  puts
  puts "When complete, download with:"
  puts "  ./tools/extract-from-snapshot.rb --download #{export_id}"
  puts
  puts "Note: Export typically takes 15-30 minutes depending on database size."

  export_id
end

def ensure_export_bucket(options)
  # Check if bucket exists (managed by CloudFormation)
  result = run_aws(options, "s3api", "head-bucket", "--bucket", EXPORT_BUCKET)

  if result.nil?
    STDERR.puts "Error: S3 bucket not found: #{EXPORT_BUCKET}"
    STDERR.puts "Make sure the CloudFormation stack is deployed with the SnapshotExportBucket resource."
    exit 1
  end
end

def get_export_role_arn(options)
  # Use the existing role from CloudFormation stack
  role_name = "e2-rds-snapshot-to-s3-role"

  result = run_aws(options, "iam", "get-role", "--role-name", role_name)

  unless result && result['Role']
    STDERR.puts "Error: IAM role not found: #{role_name}"
    STDERR.puts "Make sure the CloudFormation stack is deployed with the updated configuration."
    exit 1
  end

  result['Role']['Arn']
end

def get_or_create_kms_key(options)
  # Use the CloudFormation-managed KMS key
  alias_name = "alias/e2-snapshot-export"

  result = run_aws(options, "kms", "describe-key", "--key-id", alias_name)

  unless result && result['KeyMetadata']
    STDERR.puts "Error: KMS key not found: #{alias_name}"
    STDERR.puts "Make sure the CloudFormation stack is deployed with the SnapshotExportKMSKey resource."
    exit 1
  end

  puts "Using KMS key: #{alias_name}"
  result['KeyMetadata']['KeyId']
end

def download_export(options, export_id)
  puts "Downloading export: #{export_id}"
  puts

  FileUtils.mkdir_p(OUTPUT_DIR)

  # Download from S3
  local_path = File.join(OUTPUT_DIR, export_id)
  s3_path = "s3://#{EXPORT_BUCKET}/#{export_id}/"

  puts "Downloading from S3 to #{local_path}/"
  cmd = aws_cmd(options) + ["s3", "sync", s3_path, local_path]
  system(*cmd)

  puts
  puts "Download complete!"
  puts "Data available in: #{local_path}/"
  puts
  puts "Next steps:"
  puts "  1. Install DuckDB: brew install duckdb (or from duckdb.org)"
  puts "  2. Query the data:"
  puts "     duckdb -c \"SELECT COUNT(*) FROM parquet_scan('#{local_path}/everything.node/*.parquet')\""
  puts "  3. Extract writeups to JSON:"
  puts "     # TODO: Create extraction script for Parquet -> JSON"
end

# Main execution
puts "RDS Snapshot Export Tool"
puts "=" * 60
puts

if options[:list]
  list_snapshots(options)
elsif options[:export_id]
  download_export(options, options[:export_id])
elsif options[:latest]
  snapshot = get_latest_snapshot(options)
  puts "Latest automated snapshot: #{snapshot['DBSnapshotIdentifier']}"
  created = Time.parse(snapshot['SnapshotCreateTime']).strftime('%Y-%m-%d %H:%M:%S')
  puts "Created: #{created}"
  puts
  export_snapshot(options, snapshot['DBSnapshotIdentifier'])
elsif options[:snapshot_id]
  export_snapshot(options, options[:snapshot_id])
else
  puts "Error: No action specified"
  puts "Use --help for usage information"
  exit 1
end
