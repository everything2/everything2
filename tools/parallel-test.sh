#!/bin/bash
#
# Parallel Test Runner
# Runs smoke tests → perl tests on left, react tests on right
#
# Usage: ./tools/parallel-test.sh

# Don't use set -e because we want to display results even when tests fail
# Instead, we'll explicitly check exit codes and exit with appropriate code at the end

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Create temp files for output
PERL_OUTPUT=$(mktemp)
REACT_OUTPUT=$(mktemp)

# Cleanup on exit
cleanup() {
  rm -f "$PERL_OUTPUT" "$REACT_OUTPUT"
}
trap cleanup EXIT

# Function to run perl tests (smoke + unit)
run_perl_tests() {
  {
    echo "=== Running Smoke Tests ==="
    ./tools/smoke-test.rb 2>&1
    SMOKE_EXIT=$?
    if [ $SMOKE_EXIT -eq 0 ]; then
      echo -e "${GREEN}✓ Smoke tests passed${NC}"
    else
      echo -e "${RED}✗ Smoke tests failed${NC}"
      exit 1
    fi

    echo ""
    echo "=== Running Perl Unit Tests ==="
    # Run timeout INSIDE container to avoid exit code propagation issues
    # between timeout -> docker exec -> perl boundaries
    docker exec e2devapp timeout 120 perl -I /var/everything/ecore -I /var/libraries/lib/perl5 /var/everything/t/run.pl 2>&1
    PERL_TEST_EXIT=$?
    if [ $PERL_TEST_EXIT -eq 0 ]; then
      echo -e "${GREEN}✓ Perl tests passed${NC}"
    elif [ $PERL_TEST_EXIT -eq 124 ]; then
      echo -e "${RED}✗ Perl tests timed out${NC}"
      exit 1
    else
      echo -e "${RED}✗ Perl tests failed${NC}"
      exit 1
    fi
  } > "$PERL_OUTPUT" 2>&1
}

# Function to run react tests
run_react_tests() {
  {
    echo "=== Running React Tests ==="
    npm test -- --passWithNoTests 2>&1
    REACT_EXIT=$?
    if [ $REACT_EXIT -eq 0 ]; then
      echo -e "${GREEN}✓ React tests passed${NC}"
    else
      echo -e "${RED}✗ React tests failed${NC}"
      exit 1
    fi
  } > "$REACT_OUTPUT" 2>&1
}

# Print header
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     Everything2 Parallel Test Runner                       ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Running Perl and React tests in parallel...${NC}"
echo ""

# Run both test suites in background
run_perl_tests &
PERL_PID=$!

run_react_tests &
REACT_PID=$!

# Detect if we're in an interactive terminal
# VS Code embedded terminal and CI environments don't support fancy spinners
INTERACTIVE=true
if [ ! -t 1 ] || [ "$TERM" = "dumb" ] || [ -n "$CI" ] || [ -n "$VSCODE_PID" ]; then
  INTERACTIVE=false
fi

if [ "$INTERACTIVE" = true ]; then
  # Monitor progress with rotating indicator
  spin() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
      local temp=${spinstr#?}
      printf " [%c]  " "$spinstr"
      spinstr=$temp${spinstr%"$temp"}
      sleep $delay
      printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
  }

  echo -ne "${BLUE}Perl/Smoke:${NC} "
  spin $PERL_PID &
  PERL_SPIN_PID=$!

  echo -ne "  ${BLUE}React:${NC} "
  spin $REACT_PID &
  REACT_SPIN_PID=$!

  # Wait for both to complete
  wait $PERL_PID
  PERL_EXIT=$?
  kill $PERL_SPIN_PID 2>/dev/null || true

  wait $REACT_PID
  REACT_EXIT=$?
  kill $REACT_SPIN_PID 2>/dev/null || true

  echo ""
  echo ""
else
  # Simple progress for non-interactive terminals
  echo -e "${BLUE}Perl/Smoke:${NC} Running..."
  echo -e "${BLUE}React:${NC} Running..."
  echo ""

  # Wait for both to complete and capture exit codes
  wait $PERL_PID
  PERL_EXIT=$?

  wait $REACT_PID
  REACT_EXIT=$?

  echo ""
fi

# Display results side-by-side
echo -e "${BOLD}═══════════════════════════ Results ═══════════════════════════${NC}"
echo ""

# Perl tests result
echo -e "${BOLD}${BLUE}Perl Tests (Smoke + Unit):${NC}"
if [ $PERL_EXIT -eq 0 ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  # Show summary only
  grep -E "(Running tests with|Running.*tests|Result: PASS|All tests successful)" "$PERL_OUTPUT" || tail -20 "$PERL_OUTPUT"
else
  echo -e "${RED}✗ FAILED${NC}"
  echo ""
  # Show specific failures
  if grep -q "FAILED" "$PERL_OUTPUT"; then
    echo -e "${YELLOW}Failed tests:${NC}"
    grep -E "(FAILED|not ok|#   Failed test)" "$PERL_OUTPUT" | head -30
    echo ""
  fi
  if grep -q "Smoke tests failed" "$PERL_OUTPUT"; then
    echo -e "${YELLOW}Smoke test failures:${NC}"
    grep -B5 -A5 "ERROR\|FAILED" "$PERL_OUTPUT" | head -40
    echo ""
  fi
  echo -e "${YELLOW}Last 30 lines of output:${NC}"
  tail -30 "$PERL_OUTPUT"
fi

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# React tests result
echo -e "${BOLD}${BLUE}React Tests:${NC}"
if [ $REACT_EXIT -eq 0 ]; then
  echo -e "${GREEN}✓ PASSED${NC}"
  # Show summary only
  grep -E "(Test Suites:|Tests:|Time:)" "$REACT_OUTPUT" || tail -10 "$REACT_OUTPUT"
else
  echo -e "${RED}✗ FAILED${NC}"
  echo ""
  # Show specific failures
  if grep -q "FAIL" "$REACT_OUTPUT"; then
    echo -e "${YELLOW}Failed test suites:${NC}"
    grep -E "FAIL " "$REACT_OUTPUT" | head -20
    echo ""
    echo -e "${YELLOW}Test failure details:${NC}"
    grep -A3 "●" "$REACT_OUTPUT" | head -40
    echo ""
  fi
  echo -e "${YELLOW}Test summary:${NC}"
  grep -E "(Test Suites:|Tests:|Snapshots:|Time:)" "$REACT_OUTPUT" || tail -20 "$REACT_OUTPUT"
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Exit with failure if either failed
if [ $PERL_EXIT -ne 0 ] || [ $REACT_EXIT -ne 0 ]; then
  echo -e "${RED}${BOLD}Build Failed${NC}"
  echo ""
  echo "For full output:"
  echo "  Perl:  cat $PERL_OUTPUT"
  echo "  React: cat $REACT_OUTPUT"
  exit 1
else
  echo -e "${GREEN}${BOLD}✓ All Tests Passed!${NC}"
  exit 0
fi
