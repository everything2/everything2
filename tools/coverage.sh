#!/bin/bash
#
# Code Coverage Tool for Everything2
# Uses Devel::Cover to measure test coverage
#
# Usage:
#   ./tools/coverage.sh              # Run coverage and generate HTML report
#   ./tools/coverage.sh clean        # Clean coverage data
#   ./tools/coverage.sh report       # Generate report from existing data
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
COVERAGE_DB="$COVERAGE_DIR/cover_db"

# Check if container is running
CONTAINER_NAME="e2devapp"
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "Error: Container '$CONTAINER_NAME' is not running."
    echo "Start it with: ./docker/devbuild.sh"
    exit 1
fi

case "${1:-run}" in
    clean)
        echo "Cleaning coverage data..."
        rm -rf "$COVERAGE_DIR"
        echo "Coverage data cleaned."
        ;;

    report)
        if [ ! -d "$COVERAGE_DB" ]; then
            echo "Error: No coverage data found. Run coverage first."
            exit 1
        fi

        echo "Generating coverage report..."
        docker exec -w /var/everything $CONTAINER_NAME \
            bash -c "export PERL5LIB=/var/libraries/lib/perl5 && /var/libraries/bin/cover -report html -outputdir /var/everything/coverage/html -ignore_re '/var/libraries/' /var/everything/coverage/cover_db"

        echo ""
        echo "========================================="
        echo "Coverage report generated!"
        echo "Open: file://$COVERAGE_DIR/html/coverage.html"
        echo "========================================="
        ;;

    run|*)
        echo "Running tests with coverage..."
        echo ""

        # Clean old coverage data
        rm -rf "$COVERAGE_DIR"
        mkdir -p "$COVERAGE_DIR"

        # Create coverage directory in container
        docker exec $CONTAINER_NAME mkdir -p /var/everything/coverage

        # Sync code to container
        echo "Syncing code to container..."
        docker cp "$PROJECT_ROOT/t/." $CONTAINER_NAME:/var/everything/t/
        docker cp "$PROJECT_ROOT/ecore/." $CONTAINER_NAME:/var/everything/ecore/
        echo ""

        # Run tests with Devel::Cover
        echo "Running tests with coverage tracking..."
        docker exec -w /var/everything $CONTAINER_NAME \
            perl -I/var/libraries/lib/perl5 -MDevel::Cover=-db,/var/everything/coverage/cover_db,+select,'ecore',+ignore,'^/var/everything/t/' \
            t/run.pl

        # Copy coverage data back
        echo ""
        echo "Copying coverage data..."
        docker cp $CONTAINER_NAME:/var/everything/coverage/. "$COVERAGE_DIR/"

        # Generate HTML report
        echo ""
        echo "Generating HTML coverage report..."
        docker exec -w /var/everything $CONTAINER_NAME \
            bash -c "export PERL5LIB=/var/libraries/lib/perl5 && /var/libraries/bin/cover -report html -outputdir /var/everything/coverage/html -ignore_re '/var/libraries/' /var/everything/coverage/cover_db"

        # Copy HTML report
        docker cp $CONTAINER_NAME:/var/everything/coverage/html/. "$COVERAGE_DIR/html/"

        # Generate text summary
        echo ""
        echo "========================================="
        echo "Coverage Summary"
        echo "========================================="
        docker exec -w /var/everything $CONTAINER_NAME \
            bash -c "export PERL5LIB=/var/libraries/lib/perl5 && /var/libraries/bin/cover -report text -summary -ignore_re '/var/libraries/' /var/everything/coverage/cover_db"

        echo ""
        echo "========================================="
        echo "Full HTML report: file://$COVERAGE_DIR/html/coverage.html"
        echo "========================================="
        ;;
esac
