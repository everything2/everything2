#!/bin/bash
#
# Everything2 Development Build Script
#
# Usage:
#   ./docker/devbuild.sh           # Auto-detect: builds DB if needed, always builds app
#   ./docker/devbuild.sh --db-only # Build only database container
#   ./docker/devbuild.sh --app-only # Build only application container
#   ./docker/devbuild.sh --clean   # Clean all containers, images, and network
#
# Build Dependencies:
# - Database Dockerfile uses 'FROM everything2/e2app', so e2app image is built first
# - App container requires database container to be running (connects to e2devdb)
#
# The script intelligently manages dependencies:
# - Database build automatically builds app image if needed
# - Database initialization is monitored via /etc/everything/dev_db_ready flag
# - Application container waits for database to be fully ready
# - Tests run automatically after successful app build
# - Use --clean to remove all development containers and start fresh

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="/tmp/devbuild.log"

# Initialize log file
echo "=== Everything2 Development Build - $(date) ===" | tee "$LOG_FILE"
echo "Logs are being captured to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Helper function to log and display
log_and_display() {
  tee -a "$LOG_FILE"
}

# Parse command line arguments
BUILD_DB=false
BUILD_APP=false
FORCE_REBUILD=false
CLEAN_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --db-only)
      BUILD_DB=true
      shift
      ;;
    --app-only)
      BUILD_APP=true
      shift
      ;;
    --force)
      FORCE_REBUILD=true
      shift
      ;;
    --clean)
      CLEAN_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--db-only] [--app-only] [--force] [--clean]"
      exit 1
      ;;
  esac
done

# Handle clean mode
if [ "$CLEAN_ONLY" = true ]; then
  echo "========================================="
  echo "Cleaning development environment..."
  echo "========================================="

  echo "Stopping containers..."
  docker container stop e2devapp 2>/dev/null
  docker container stop e2devdb 2>/dev/null

  echo "Removing containers..."
  docker rm e2devapp 2>/dev/null
  docker rm e2devdb 2>/dev/null

  echo "Removing images..."
  docker image rm everything2/e2app 2>/dev/null
  docker image rm everything2/e2db 2>/dev/null

  echo "Removing network..."
  docker network rm e2-dev-net 2>/dev/null

  echo "Pruning Docker build cache..."
  docker builder prune --all --force

  echo ""
  echo "========================================="
  echo "Clean complete!"
  echo "========================================="
  exit 0
fi

# If no flags specified, build both (or auto-detect what's needed)
if [ "$BUILD_DB" = false ] && [ "$BUILD_APP" = false ]; then
  # Auto-detect mode: check if DB exists
  if ! docker ps --format '{{.Names}}' | grep -q '^e2devdb$'; then
    BUILD_DB=true
  fi
  BUILD_APP=true
fi

# Create network if needed
docker network inspect e2-dev-net >/dev/null 2>&1 || docker network create e2-dev-net

# Function to build application image (needed by database)
build_app_image() {
  echo "========================================="
  echo "Building application image..."
  echo "========================================="
  docker image rm everything2/e2app 2>/dev/null
  if ! docker build -t everything2/e2app -f docker/e2app/Dockerfile .; then
    echo ""
    echo "ERROR: Application image build failed!"
    exit 1
  fi
  echo ""
}

# Function to build and run application container
build_app_container() {
  echo "========================================="
  echo "Starting application container..."
  echo "========================================="
  docker container stop e2devapp 2>/dev/null
  docker rm e2devapp 2>/dev/null
  docker run -d --publish 9080:80 --publish 443:9443 --env E2_DOCKER=development --env E2_DBSERV=e2devdb --name=e2devapp --net=e2-dev-net everything2/e2app

  # Wait for container to be ready
  echo ""
  echo "Waiting for container to be ready..."
  sleep 3

  # Additional check: wait for Apache to respond
  echo "Verifying Apache is responding..."
  RETRY=0
  MAX_RETRIES=30
  until curl -sf http://localhost:9080/ > /dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
      echo "ERROR: Apache did not start within 30 seconds"
      exit 1
    fi
    sleep 1
    echo "  Still waiting... (attempt $RETRY/$MAX_RETRIES)"
  done
  echo "Apache is ready!"
  echo ""
}

# Function to build database (requires e2app image)
build_database() {
  # Database Dockerfile uses 'FROM everything2/e2app', so ensure app image exists
  if ! docker image inspect everything2/e2app >/dev/null 2>&1; then
    echo "Application image required for database build..."
    build_app_image
  fi

  echo "========================================="
  echo "Building database container..."
  echo "========================================="
  docker container stop e2devdb 2>/dev/null
  docker rm e2devdb 2>/dev/null
  docker image rm everything2/e2db 2>/dev/null
  if ! docker build -t everything2/e2db -f docker/e2db/Dockerfile .; then
    echo ""
    echo "ERROR: Database image build failed!"
    exit 1
  fi
  docker run -d --publish 9306:3306 --env E2_DOCKER=development --env E2_DBSERV=localhost --name=e2devdb --net=e2-dev-net everything2/e2db

  echo ""
  echo "Waiting for database to initialize (nodepack + seeds)..."

  # Wait for the dev_db_ready flag file to be created
  WAIT_TIME=0
  MAX_WAIT=300  # 5 minutes maximum
  while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if docker exec e2devdb test -f /etc/everything/dev_db_ready 2>/dev/null; then
      echo "Database initialization complete!"
      break
    fi
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
    if [ $((WAIT_TIME % 10)) -eq 0 ]; then
      echo "  Still waiting... (${WAIT_TIME}s elapsed)"
    fi
  done

  if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "WARNING: Database initialization timeout after ${MAX_WAIT}s"
    echo "Proceeding anyway, but database may not be fully ready"
  fi
  echo ""
}

# Function to build application (image + container)
build_application() {
  build_app_image
  build_app_container
}

# Execute builds based on flags
# Note: Database build requires e2app image, so it will build app image if needed
if [ "$BUILD_DB" = true ]; then
  build_database
fi

if [ "$BUILD_APP" = true ]; then
  # Verify database container is running before starting app container
  if ! docker ps --format '{{.Names}}' | grep -q '^e2devdb$'; then
    echo "ERROR: Database container is required but not running."
    echo "The app container needs the database to connect to."
    echo "Run './docker/devbuild.sh' without flags to build both."
    exit 1
  fi

  build_application

  # Run all tests in parallel (smoke + perl + react)
  echo "========================================="
  echo "Running test suite..."
  echo "========================================="

  # Ensure output is not buffered
  stdbuf -o0 -e0 $SCRIPT_DIR/../tools/parallel-test.sh
  TEST_EXIT=$?

  if [ $TEST_EXIT -ne 0 ]; then
    echo ""
    echo "========================================="
    echo "TESTS FAILED"
    echo "========================================="
    echo "Build completed but tests failed."
    echo "See output above for details."
    echo ""
    echo "To re-run tests: ./tools/parallel-test.sh"
    exit 1
  fi
fi

echo ""
echo "========================================="
echo "Build complete!"
if [ "$BUILD_DB" = true ]; then
  echo "Database available at: localhost:9306"
fi
if [ "$BUILD_APP" = true ]; then
  echo "Application available at: http://localhost:9080"
fi
echo "========================================="
