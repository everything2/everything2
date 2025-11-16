#!/bin/bash
#
# Test Runner for Everything2
# Executes Perl and React tests
#
# Usage:
#   ./docker/run-tests.sh              # Run all tests (Perl + React)
#   ./docker/run-tests.sh 012          # Run specific Perl test by number
#   ./docker/run-tests.sh sql          # Run Perl tests matching pattern
#   ./docker/run-tests.sh --react-only # Run only React tests
#   ./docker/run-tests.sh --perl-only  # Run only Perl tests
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONTAINER_NAME="e2devapp"

# Parse command line arguments
RUN_REACT=true
RUN_PERL=true

if [ "$1" = "--react-only" ]; then
    RUN_PERL=false
    shift
elif [ "$1" = "--perl-only" ]; then
    RUN_REACT=false
    shift
fi

# Check if container is running (only needed for Perl tests)
if [ "$RUN_PERL" = true ]; then
    if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo "Error: Container '$CONTAINER_NAME' is not running."
        echo "Start it with: ./docker/devbuild.sh"
        exit 1
    fi
fi

# Run Perl tests if requested
if [ "$RUN_PERL" = true ]; then
    # Sync local test files and code changes to container
    echo "Syncing code changes to container..."
    docker cp "$PROJECT_ROOT/t/." $CONTAINER_NAME:/var/everything/t/
    docker cp "$PROJECT_ROOT/ecore/." $CONTAINER_NAME:/var/everything/ecore/
    echo ""

    # Determine which tests to run
    if [ -z "$1" ]; then
        # Run all tests using run.pl
        echo "========================================="
        echo "Running Perl tests in e2devapp container..."
        echo "========================================="
        docker exec -w /var/everything -e E2_DEV_LOG=/tmp/test-runner.log $CONTAINER_NAME perl t/run.pl
        echo ""
    else
        # Run specific test(s) matching the pattern
        TEST_PATTERN="$1"
        echo "========================================="
        echo "Running Perl tests matching pattern: $TEST_PATTERN"
        echo "========================================="

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
            echo "Running: $TEST"
            docker exec -w /var/everything -e E2_DEV_LOG=/tmp/test-runner.log $CONTAINER_NAME perl -I/var/libraries/lib/perl5 "$TEST"
            echo ""
        done
    fi
fi

# Run React tests if requested
if [ "$RUN_REACT" = true ]; then
    echo "========================================="
    echo "Running React tests (Jest)..."
    echo "========================================="

    # Check if node_modules exists, install if needed
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        echo "Installing npm dependencies..."
        cd "$PROJECT_ROOT"
        npm install
        echo ""
    fi

    # Run Jest tests
    cd "$PROJECT_ROOT"
    if npm test -- --ci --coverage --maxWorkers=2; then
        echo ""
        echo "React tests passed!"
    else
        echo ""
        echo "ERROR: React tests failed!"
        exit 1
    fi
    echo ""
fi

echo "========================================="
if [ "$RUN_PERL" = true ] && [ "$RUN_REACT" = true ]; then
    echo "All tests complete!"
elif [ "$RUN_PERL" = true ]; then
    echo "Perl tests complete!"
elif [ "$RUN_REACT" = true ]; then
    echo "React tests complete!"
fi
echo "========================================="
