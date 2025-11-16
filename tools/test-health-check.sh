#!/bin/bash

# Health Check Testing Script for Everything2
# Tests the /health endpoint locally or on running containers
#
# Usage:
#   ./tools/test-health-check.sh [options] [url]
#
# Options:
#   --basic        Test basic health check (default)
#   --detailed     Test detailed health check
#   --db           Test database connectivity
#   --watch        Continuously monitor health (1 second intervals)
#   --help         Show this help
#
# Examples:
#   ./tools/test-health-check.sh                                  # Test localhost
#   ./tools/test-health-check.sh --detailed                       # Detailed check
#   ./tools/test-health-check.sh --db                            # Test with DB check
#   ./tools/test-health-check.sh --watch                         # Continuous monitoring
#   ./tools/test-health-check.sh https://everything2.com/health  # Test production

set -e

# Default options
MODE="basic"
URL=""
WATCH=false

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case $1 in
    --basic)
      MODE="basic"
      shift
      ;;
    --detailed)
      MODE="detailed"
      shift
      ;;
    --db)
      MODE="db"
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    --help|-h)
      echo "Health Check Testing Script for Everything2"
      echo
      echo "Usage: $0 [options] [url]"
      echo
      echo "Options:"
      echo "  --basic       Test basic health check (default)"
      echo "  --detailed    Test detailed health check"
      echo "  --db          Test database connectivity"
      echo "  --watch       Continuously monitor health (1 second intervals)"
      echo "  --help        Show this help"
      echo
      echo "Examples:"
      echo "  $0                                  # Test localhost"
      echo "  $0 --detailed                       # Detailed check"
      echo "  $0 --db                            # Test with DB check"
      echo "  $0 --watch                         # Continuous monitoring"
      echo "  $0 https://everything2.com/health  # Test production"
      exit 0
      ;;
    *)
      URL="$1"
      shift
      ;;
  esac
done

# Determine base URL
if [ -z "$URL" ]; then
  # Default to /health.pl (the actual endpoint)
  URL="http://localhost/health.pl"
fi

# Ensure URL ends with /health.pl or /health
if [[ ! "$URL" =~ /health ]]; then
  URL="${URL%/}/health.pl"
fi

# Build query parameters based on mode
QUERY_PARAMS=""
case $MODE in
  detailed)
    QUERY_PARAMS="?detailed=1"
    ;;
  db)
    QUERY_PARAMS="?detailed=1&db=1"
    ;;
esac

FULL_URL="${URL}${QUERY_PARAMS}"

# Function to perform health check
do_health_check() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  echo "================================================================================"
  echo "[$timestamp] Testing: $FULL_URL"
  echo "================================================================================"

  # Perform the curl request
  HTTP_CODE=$(curl -s -o /tmp/health-response.json -w '%{http_code}' "$FULL_URL" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ HTTP Status: $HTTP_CODE OK"
  elif [ "$HTTP_CODE" = "503" ]; then
    echo "✗ HTTP Status: $HTTP_CODE Service Unavailable"
  elif [ "$HTTP_CODE" = "000" ]; then
    echo "✗ Connection failed - is the server running?"
    return 1
  else
    echo "⚠ HTTP Status: $HTTP_CODE"
  fi

  # Display response if JSON
  if [ -f /tmp/health-response.json ]; then
    echo
    echo "Response:"
    if command -v jq > /dev/null 2>&1; then
      cat /tmp/health-response.json | jq .
    else
      cat /tmp/health-response.json
      echo
    fi
    rm -f /tmp/health-response.json
  fi

  # Show timing information
  echo
  TIME_TOTAL=$(curl -s -o /dev/null -w '%{time_total}' "$FULL_URL" 2>/dev/null || echo "0")
  echo "Response time: ${TIME_TOTAL}s"

  echo

  if [ "$HTTP_CODE" = "200" ]; then
    return 0
  else
    return 1
  fi
}

# Main execution
if [ "$WATCH" = true ]; then
  echo "Continuous health check monitoring (Ctrl+C to stop)"
  echo

  CONSECUTIVE_FAILURES=0
  TOTAL_CHECKS=0
  FAILED_CHECKS=0

  while true; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if do_health_check; then
      CONSECUTIVE_FAILURES=0
    else
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      FAILED_CHECKS=$((FAILED_CHECKS + 1))

      echo "⚠ Consecutive failures: $CONSECUTIVE_FAILURES"

      if [ $CONSECUTIVE_FAILURES -ge 5 ]; then
        echo "❌ ALERT: 5 consecutive health check failures detected!"
      fi
    fi

    echo "Summary: $FAILED_CHECKS failures in $TOTAL_CHECKS checks"
    echo

    sleep 1
  done
else
  # Single health check
  if do_health_check; then
    echo "✓ Health check passed"
    exit 0
  else
    echo "✗ Health check failed"
    exit 1
  fi
fi
