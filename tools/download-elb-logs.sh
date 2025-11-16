#!/bin/bash
#
# ELB Log Downloader for Everything2
# Downloads Elastic Load Balancing logs from S3 for offline analysis
#
# Usage:
#   ./tools/download-elb-logs.sh              # Download to current directory
#   ./tools/download-elb-logs.sh <dest>       # Download to specified directory
#   ./tools/download-elb-logs.sh --help       # Show this help
#
# Examples:
#   ./tools/download-elb-logs.sh                    # Download to .
#   ./tools/download-elb-logs.sh ../e2-loganalysis  # Download to ../e2-loganalysis
#
# Requirements:
#   - AWS CLI installed and configured with credentials
#   - Read access to s3://elblogs.everything2.com
#

set -e

S3_BUCKET="s3://elblogs.everything2.com"

# Show usage
show_usage() {
    echo "Usage: $0 [destination]"
    echo ""
    echo "Downloads ELB logs from $S3_BUCKET to local directory for analysis."
    echo ""
    echo "Arguments:"
    echo "  destination    Target directory (default: current directory)"
    echo ""
    echo "Examples:"
    echo "  $0                     # Download to current directory"
    echo "  $0 ../e2-loganalysis   # Download to ../e2-loganalysis"
    echo ""
    echo "Note: This script syncs FROM S3 TO local, so nothing is deleted from S3."
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed."
    echo "Install it with: pip install awscli"
    echo "Or see: https://aws.amazon.com/cli/"
    exit 1
fi

# Get destination directory (default to current directory)
DEST_DIR="${1:-.}"

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo "Creating destination directory: $DEST_DIR"
    mkdir -p "$DEST_DIR"
fi

# Convert to absolute path for clearer output
DEST_DIR_ABS="$(cd "$DEST_DIR" && pwd)"

echo "========================================="
echo "Everything2 ELB Log Downloader"
echo "========================================="
echo "Source:      $S3_BUCKET"
echo "Destination: $DEST_DIR_ABS"
echo ""
echo "Starting sync (this may take a while)..."
echo ""

# Sync from S3 to local directory
# --no-progress is not used so we see progress
# Syncing FROM S3 TO local never deletes from S3
aws s3 sync "$S3_BUCKET" "$DEST_DIR" --no-progress

echo ""
echo "========================================="
echo "Sync complete!"
echo "Logs downloaded to: $DEST_DIR_ABS"
echo "========================================="
echo ""
echo "You can now analyze the logs locally."
echo ""
echo "Tip: To see the size of downloaded logs:"
echo "  du -sh $DEST_DIR"
