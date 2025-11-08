#!/bin/bash
#
# Test Runner for Everything2
# Executes tests inside the e2devapp Docker container
#
# Usage:
#   ./docker/run-tests.sh              # Run all tests
#   ./docker/run-tests.sh 012          # Run specific test by number
#   ./docker/run-tests.sh sql          # Run tests matching pattern
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="e2devapp"

# Check if container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "Error: Container '$CONTAINER_NAME' is not running."
    echo "Start it with: ./docker/devbuild.sh"
    exit 1
fi

# Sync local test files and code changes to container
echo "Syncing code changes to container..."
docker cp "$PROJECT_ROOT/t/." $CONTAINER_NAME:/var/everything/t/
docker cp "$PROJECT_ROOT/ecore/." $CONTAINER_NAME:/var/everything/ecore/
echo ""

# Determine which tests to run
if [ -z "$1" ]; then
    # Run all tests using run.pl
    echo "Running all tests in e2devapp container..."
    docker exec -w /var/everything $CONTAINER_NAME perl t/run.pl
else
    # Run specific test(s) matching the pattern
    TEST_PATTERN="$1"
    echo "Running tests matching pattern: $TEST_PATTERN"

    # Find matching test files
    TESTS=$(docker exec -w /var/everything $CONTAINER_NAME find t -maxdepth 1 -name "*${TEST_PATTERN}*.t" -type f | sort)

    if [ -z "$TESTS" ]; then
        echo "Error: No tests found matching pattern '$TEST_PATTERN'"
        exit 1
    fi

    echo "Found tests:"
    echo "$TESTS"
    echo ""

    # Run each test
    for TEST in $TESTS; do
        echo "========================================="
        echo "Running: $TEST"
        echo "========================================="
        docker exec -w /var/everything $CONTAINER_NAME perl -I/var/libraries/lib/perl5 "$TEST"
        echo ""
    done
fi

echo "Tests complete!"
