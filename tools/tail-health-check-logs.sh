#!/bin/bash

# Health Check CloudWatch Logs Viewer
# Tails CloudWatch logs for health check failures and slow responses
#
# Usage:
#   ./tools/tail-health-check-logs.sh [options]
#
# Options:
#   --follow         Follow logs in real-time (default)
#   --since DURATION Show logs since duration (e.g., '1h', '30m', '1d')
#   --failed         Show only failed health checks
#   --slow           Show only slow health checks (>1s)
#   --all            Show all health check events (failed + slow)
#   --region REGION  AWS region (default: us-west-2)
#   --help           Show this help
#
# Examples:
#   ./tools/tail-health-check-logs.sh                    # Follow all logs
#   ./tools/tail-health-check-logs.sh --failed           # Show only failures
#   ./tools/tail-health-check-logs.sh --since 1h         # Show last hour
#   ./tools/tail-health-check-logs.sh --since 30m --slow # Slow checks in last 30 min
#
# Note: Requires AWS CLI configured with appropriate credentials

set -e

# Default options
FOLLOW=true
SINCE=""
FILTER=""
REGION="us-west-2"
LOG_GROUP="/aws/fargate/e2-health-check"

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --follow)
      FOLLOW=true
      shift
      ;;
    --since)
      SINCE="$2"
      FOLLOW=false
      shift 2
      ;;
    --failed)
      FILTER="FAILED"
      shift
      ;;
    --slow)
      FILTER="SLOW"
      shift
      ;;
    --all)
      FILTER=""
      shift
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --help|-h)
      echo "Health Check CloudWatch Logs Viewer"
      echo ""
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --follow         Follow logs in real-time (default)"
      echo "  --since DURATION Show logs since duration (e.g., '1h', '30m', '1d')"
      echo "  --failed         Show only failed health checks"
      echo "  --slow           Show only slow health checks (>1s)"
      echo "  --all            Show all health check events (failed + slow)"
      echo "  --region REGION  AWS region (default: us-west-2)"
      echo "  --help           Show this help"
      echo ""
      echo "Examples:"
      echo "  $0                    # Follow all logs"
      echo "  $0 --failed           # Show only failures"
      echo "  $0 --since 1h         # Show last hour"
      echo "  $0 --since 30m --slow # Slow checks in last 30 min"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    echo "Install with: pip install awscli"
    exit 1
fi

# Build the command
CMD="aws logs tail '$LOG_GROUP' --region '$REGION'"

if [ "$FOLLOW" = true ]; then
  CMD="$CMD --follow"
fi

if [ -n "$SINCE" ]; then
  CMD="$CMD --since '$SINCE'"
fi

if [ "$FILTER" = "FAILED" ]; then
  CMD="$CMD --filter-pattern '\"FAILED\"'"
elif [ "$FILTER" = "SLOW" ]; then
  CMD="$CMD --filter-pattern '\"SLOW\"'"
fi

# Display header
echo "================================================================================"
echo "Health Check CloudWatch Logs"
echo "================================================================================"
echo "Log Group: $LOG_GROUP"
echo "Region: $REGION"
if [ -n "$SINCE" ]; then
  echo "Since: $SINCE"
fi
if [ -n "$FILTER" ]; then
  echo "Filter: $FILTER"
fi
if [ "$FOLLOW" = true ]; then
  echo "Mode: Following (press Ctrl+C to stop)"
fi
echo "================================================================================"
echo ""

# Execute the command
eval "$CMD"
