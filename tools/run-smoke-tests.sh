#!/bin/bash
# Wrapper script to run smoke tests with proper error handling

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_URL="${1:-http://localhost:9080}"
MAX_RETRIES=30
RETRY_DELAY=2
CONTAINER_NAME="${E2_CONTAINER_NAME:-e2devapp}"

echo "============================================"
echo "Everything2 Smoke Test Runner"
echo "============================================"
echo "Container: $CONTAINER_NAME"
echo "Base URL: $BASE_URL"
echo ""

# Function to check Apache status in container
check_apache_status() {
  echo "Checking Apache status in container..."

  # Check if container exists
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '$CONTAINER_NAME' not found"
    echo ""
    echo "Available containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    return 1
  fi

  # Check if container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "ERROR: Container '$CONTAINER_NAME' exists but is not running"
    echo ""
    echo "Container status:"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    return 1
  fi

  # Check if Apache processes are running
  if docker exec "$CONTAINER_NAME" pgrep -f apache > /dev/null 2>&1; then
    echo "✓ Apache is running"
    return 0
  else
    echo "✗ Apache is NOT running"
    return 1
  fi
}

# Function to display Apache errors
show_apache_errors() {
  echo ""
  echo "============================================"
  echo "Apache Diagnostics"
  echo "============================================"

  # Test Apache configuration
  echo ""
  echo "Testing Apache configuration..."
  echo "----------------------------------------"
  if docker exec "$CONTAINER_NAME" apachectl configtest 2>&1 | tee /tmp/apache_configtest.log; then
    echo "✓ Apache configuration is valid"
  else
    echo ""
    echo "✗ Apache configuration test FAILED"
    echo ""
    echo "Configuration errors:"
    cat /tmp/apache_configtest.log | grep -A5 "Syntax error\|Global symbol\|String found\|syntax error" || echo "See full output above"
  fi

  # Check Apache error logs
  echo ""
  echo "Recent Apache error log entries:"
  echo "----------------------------------------"
  if docker exec "$CONTAINER_NAME" test -f /etc/apache2/logs/error.log 2>/dev/null; then
    docker exec "$CONTAINER_NAME" tail -50 /etc/apache2/logs/error.log 2>/dev/null || echo "(no error log entries)"
  else
    echo "(error.log not found - Apache may not have started)"
  fi

  # Check if there are Perl compilation errors
  echo ""
  echo "Checking for Perl compilation errors:"
  echo "----------------------------------------"
  if grep -q "Global symbol\|syntax error\|Compilation failed" /tmp/apache_configtest.log 2>/dev/null; then
    echo "✗ Perl compilation errors detected:"
    grep -A2 "Global symbol\|syntax error\|Compilation failed" /tmp/apache_configtest.log | head -30

    # Try to extract the specific file and line causing issues
    echo ""
    echo "Problem locations:"
    grep "at /var/everything/.*\.pm line" /tmp/apache_configtest.log | sort -u | head -10 || true
  else
    echo "✓ No Perl compilation errors detected"
  fi

  # Try to start Apache and capture output
  echo ""
  echo "Attempting to start Apache..."
  echo "----------------------------------------"
  if docker exec "$CONTAINER_NAME" apachectl start 2>&1 | tee /tmp/apache_start.log; then
    echo "✓ Apache start command succeeded"
    sleep 2
    if docker exec "$CONTAINER_NAME" pgrep -f apache > /dev/null 2>&1; then
      echo "✓ Apache processes are now running"
    else
      echo "✗ Apache processes not detected after start"
    fi
  else
    echo "✗ Apache start command failed"
    cat /tmp/apache_start.log
  fi
}

# Main execution
echo "Checking Apache status..."
if ! check_apache_status; then
  show_apache_errors
  echo ""
  echo "============================================"
  echo "FATAL: Apache is not running"
  echo "============================================"
  echo "Fix the Apache/Perl errors above before running smoke tests"
  exit 1
fi

echo ""
echo "Waiting for application to be ready..."

# Wait for server to be available
for i in $(seq 1 $MAX_RETRIES); do
  if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null | grep -q "200\|302\|301"; then
    echo "✓ Application is responding"
    sleep 2  # Give it a moment to fully initialize
    break
  fi

  if [ $i -eq $MAX_RETRIES ]; then
    echo ""
    echo "ERROR: Application did not respond within expected time"
    echo ""
    echo "Final Apache status check:"
    check_apache_status || true
    echo ""
    show_apache_errors
    exit 1
  fi

  echo "  Attempt $i/$MAX_RETRIES - waiting ${RETRY_DELAY}s..."
  sleep $RETRY_DELAY
done

# Run smoke tests
echo ""
ruby "$SCRIPT_DIR/smoke-test.rb" "$BASE_URL"
