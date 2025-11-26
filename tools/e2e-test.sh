#!/bin/bash
#
# E2E Test Runner for Everything2
#
# Runs Playwright end-to-end tests against the development environment.
# Tests must be run from the host (not inside Docker container) since
# Playwright needs to launch browser instances.
#
# Usage:
#   ./tools/e2e-test.sh                    # Run all E2E tests
#   ./tools/e2e-test.sh navigation         # Run specific test file
#   ./tools/e2e-test.sh --headed          # Run with visible browser
#   ./tools/e2e-test.sh --debug           # Run in debug mode (Playwright Inspector)
#   ./tools/e2e-test.sh --ui              # Run in UI mode (interactive)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$PROJECT_ROOT"

echo -e "${BLUE}=== Everything2 E2E Test Runner ===${NC}"
echo ""

# Check if Playwright is installed
if [ ! -d "node_modules/@playwright" ]; then
  echo -e "${YELLOW}⚠️  Playwright not found. Installing...${NC}"
  npm install
  echo ""
fi

# Check if Playwright browsers are installed (run quietly, install if needed)
if [ ! -d "node_modules/playwright-core/.local-browsers" ] && [ ! -d "$HOME/.cache/ms-playwright" ]; then
  echo -e "${YELLOW}⚠️  Playwright browsers not installed. Installing Chromium...${NC}"
  node node_modules/@playwright/test/cli.js install chromium 2>/dev/null || {
    echo -e "${YELLOW}Note: Browser installation may require running: npx playwright install chromium${NC}"
  }
  echo ""
fi

# Check if development server is running
echo -e "${BLUE}Checking development environment...${NC}"
if ! docker ps | grep -q e2devapp; then
  echo -e "${RED}✗ Docker container 'e2devapp' is not running${NC}"
  echo -e "${YELLOW}  Run './docker/devbuild.sh' to start the development environment${NC}"
  exit 1
fi

# Check if the app is responding
if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:9080/ | grep -q "200"; then
  echo -e "${RED}✗ Development server not responding at http://localhost:9080${NC}"
  echo -e "${YELLOW}  Check Docker logs: docker logs e2devapp${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Development environment ready${NC}"
echo ""

# Parse arguments
MODE="test"
ARGS=()
TEST_FILE=""

for arg in "$@"; do
  case $arg in
    --headed)
      ARGS+=("--headed")
      ;;
    --debug)
      MODE="debug"
      ;;
    --ui)
      MODE="ui"
      ;;
    --help|-h)
      echo "Usage: $0 [options] [test-file]"
      echo ""
      echo "Options:"
      echo "  --headed        Run tests with visible browser"
      echo "  --debug         Run tests in debug mode (Playwright Inspector)"
      echo "  --ui            Run tests in UI mode (interactive)"
      echo "  --help, -h      Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Run all E2E tests"
      echo "  $0 navigation         # Run navigation.spec.js tests"
      echo "  $0 e2e-users          # Run e2e-users.spec.js tests"
      echo "  $0 --headed           # Run all tests with visible browser"
      echo "  $0 --debug navigation # Debug navigation tests"
      echo ""
      exit 0
      ;;
    *)
      if [[ ! $arg == --* ]]; then
        TEST_FILE="$arg"
      fi
      ;;
  esac
done

# Build test command based on mode
case $MODE in
  debug)
    echo -e "${BLUE}Running E2E tests in DEBUG mode...${NC}"
    echo -e "${YELLOW}Playwright Inspector will open. Use it to step through tests.${NC}"
    echo ""
    if [ -n "$TEST_FILE" ]; then
      npx playwright test "tests/e2e/${TEST_FILE}.spec.js" --debug "${ARGS[@]}"
    else
      npx playwright test tests/e2e/ --debug "${ARGS[@]}"
    fi
    ;;
  ui)
    echo -e "${BLUE}Running E2E tests in UI mode...${NC}"
    echo -e "${YELLOW}Playwright UI will open. Select tests to run interactively.${NC}"
    echo ""
    if [ -n "$TEST_FILE" ]; then
      npx playwright test "tests/e2e/${TEST_FILE}.spec.js" --ui "${ARGS[@]}"
    else
      npx playwright test tests/e2e/ --ui "${ARGS[@]}"
    fi
    ;;
  test)
    echo -e "${BLUE}Running E2E tests...${NC}"
    echo ""
    if [ -n "$TEST_FILE" ]; then
      echo -e "${BLUE}Test file: tests/e2e/${TEST_FILE}.spec.js${NC}"
      npx playwright test "tests/e2e/${TEST_FILE}.spec.js" "${ARGS[@]}"
    else
      echo -e "${BLUE}Running all E2E tests in tests/e2e/${NC}"
      npx playwright test tests/e2e/ "${ARGS[@]}"
    fi
    ;;
esac

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✓ All E2E tests passed!${NC}"
else
  echo -e "${RED}✗ Some E2E tests failed${NC}"
  echo ""
  echo -e "${YELLOW}Tips for debugging:${NC}"
  echo "  • Run with --headed to see browser: ./tools/e2e-test.sh --headed"
  echo "  • Run in debug mode: ./tools/e2e-test.sh --debug"
  echo "  • Run specific test: ./tools/e2e-test.sh navigation"
  echo "  • Check test report: npx playwright show-report"
  echo "  • View screenshots: ls -la test-results/"
fi

exit $EXIT_CODE
