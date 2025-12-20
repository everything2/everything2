#!/bin/bash
#
# Generate Coverage Badges
# Creates coverage badges in SVG format for README.md
#
# Usage:
#   ./tools/generate-coverage-badges.sh
#
# Generates:
#   - coverage/badges/perl-coverage.svg
#   - coverage/badges/react-coverage.svg
#   - coverage/COVERAGE-SUMMARY.md
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
BADGE_DIR="$COVERAGE_DIR/badges"

# Create badge directory
mkdir -p "$BADGE_DIR"

echo "Generating coverage badges..."

# Function to generate SVG badge
generate_badge() {
    local label="$1"
    local percentage="$2"
    local filename="$3"

    # Determine color based on coverage percentage
    local color
    if (( $(echo "$percentage >= 80" | bc -l) )); then
        color="#4c1"  # Green
    elif (( $(echo "$percentage >= 60" | bc -l) )); then
        color="#97ca00"  # Yellow-green
    elif (( $(echo "$percentage >= 40" | bc -l) )); then
        color="#dfb317"  # Yellow
    elif (( $(echo "$percentage >= 20" | bc -l) )); then
        color="#fe7d37"  # Orange
    else
        color="#e05d44"  # Red
    fi

    # Calculate widths (approximate)
    local label_width=95
    local value_width=60
    local total_width=$((label_width + value_width))

    # Generate SVG
    cat > "$filename" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="$total_width" height="20">
    <linearGradient id="b" x2="0" y2="100%">
        <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
        <stop offset="1" stop-opacity=".1"/>
    </linearGradient>
    <mask id="a">
        <rect width="$total_width" height="20" rx="3" fill="#fff"/>
    </mask>
    <g mask="url(#a)">
        <path fill="#555" d="M0 0h${label_width}v20H0z"/>
        <path fill="$color" d="M${label_width} 0h${value_width}v20H${label_width}z"/>
        <path fill="url(#b)" d="M0 0h${total_width}v20H0z"/>
    </g>
    <g fill="#fff" text-anchor="middle" font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
        <text x="$((label_width/2))" y="15" fill="#010101" fill-opacity=".3">$label</text>
        <text x="$((label_width/2))" y="14">$label</text>
        <text x="$((label_width + value_width/2))" y="15" fill="#010101" fill-opacity=".3">${percentage}%</text>
        <text x="$((label_width + value_width/2))" y="14">${percentage}%</text>
    </g>
</svg>
EOF
}

# Extract Perl coverage from coverage database
if [ -d "$COVERAGE_DIR/cover_db" ]; then
    echo "Extracting Perl coverage..."

    PERL_COVERAGE=$(docker exec e2devapp bash -c "
        cd /var/everything &&
        perl -I/var/libraries/lib/perl5 -I/var/libraries/lib/perl5/x86_64-linux-gnu-thread-multi \
        /var/libraries/bin/cover -report text -summary coverage/cover_db 2>/dev/null |
        grep '^Total' |
        awk '{print \$NF}'" 2>/dev/null || echo "0.0")

    if [ -z "$PERL_COVERAGE" ] || [ "$PERL_COVERAGE" = "n/a" ]; then
        PERL_COVERAGE="0.0"
    fi

    echo "Perl Coverage: ${PERL_COVERAGE}%"
    generate_badge "perl coverage" "$PERL_COVERAGE" "$BADGE_DIR/perl-coverage.svg"
else
    echo "No Perl coverage data found. Run './tools/coverage.sh' first."
    PERL_COVERAGE="0.0"
    generate_badge "perl coverage" "0.0" "$BADGE_DIR/perl-coverage.svg"
fi

# Extract React coverage from Jest
if [ -f "$PROJECT_ROOT/coverage/react/coverage-summary.json" ]; then
    echo "Extracting React coverage..."

    REACT_COVERAGE=$(jq -r '.total.lines.pct' "$PROJECT_ROOT/coverage/react/coverage-summary.json" 2>/dev/null || echo "0.0")

    if [ -z "$REACT_COVERAGE" ] || [ "$REACT_COVERAGE" = "null" ]; then
        REACT_COVERAGE="0.0"
    fi

    echo "React Coverage: ${REACT_COVERAGE}%"
    generate_badge "react coverage" "$REACT_COVERAGE" "$BADGE_DIR/react-coverage.svg"
else
    echo "No React coverage data found. Run 'npm test -- --coverage' first."
    REACT_COVERAGE="0.0"
    generate_badge "react coverage" "0.0" "$BADGE_DIR/react-coverage.svg"
fi

# Generate detailed Perl module coverage report
if [ -d "$COVERAGE_DIR/cover_db" ]; then
    echo "Generating detailed Perl module coverage report..."

    docker exec e2devapp bash -c "
        cd /var/everything &&
        perl -I/var/libraries/lib/perl5 -I/var/libraries/lib/perl5/x86_64-linux-gnu-thread-multi \
        /var/libraries/bin/cover -report text coverage/cover_db 2>/dev/null |
        grep -E '^(ecore/|Total)' |
        grep -v '^-' |
        head -200
    " > "$COVERAGE_DIR/PERL-MODULE-COVERAGE.txt" 2>/dev/null || echo "Error generating Perl module report"

    # Convert to markdown table
    if [ -f "$COVERAGE_DIR/PERL-MODULE-COVERAGE.txt" ]; then
        # Write header with evaluated date
        cat > "$COVERAGE_DIR/PERL-MODULE-COVERAGE.md" <<PERLMD
# Perl Module Coverage Report

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

This report shows statement coverage for each Perl module in the codebase.

## Coverage by Module

| Module | Statements | Branches | Conditions | Subroutines | POD | Total |
|--------|-----------|----------|------------|-------------|-----|-------|
PERLMD

        # Parse the text report and convert to markdown table
        docker exec e2devapp bash -c "
            cd /var/everything &&
            perl -I/var/libraries/lib/perl5 -I/var/libraries/lib/perl5/x86_64-linux-gnu-thread-multi \
            /var/libraries/bin/cover -report text coverage/cover_db 2>/dev/null |
            grep '^ecore/.*\.pm' |
            awk '{printf \"| %s | %s | %s | %s | %s | %s | %s |\\n\", \$1, \$2, \$4, \$6, \$8, \$10, \$NF}'
        " >> "$COVERAGE_DIR/PERL-MODULE-COVERAGE.md" 2>/dev/null || true

        echo "" >> "$COVERAGE_DIR/PERL-MODULE-COVERAGE.md"

        # Add total line
        docker exec e2devapp bash -c "
            cd /var/everything &&
            perl -I/var/libraries/lib/perl5 -I/var/libraries/lib/perl5/x86_64-linux-gnu-thread-multi \
            /var/libraries/bin/cover -report text coverage/cover_db 2>/dev/null |
            grep '^Total' |
            awk '{printf \"| **Total** | **%s** | **%s** | **%s** | **%s** | **%s** | **%s** |\\n\", \$2, \$4, \$6, \$8, \$10, \$NF}'
        " >> "$COVERAGE_DIR/PERL-MODULE-COVERAGE.md" 2>/dev/null || true

        cat >> "$COVERAGE_DIR/PERL-MODULE-COVERAGE.md" <<'PERLMD2'

## How to Improve Coverage

### High Priority Modules (Target: >80%)
- `Everything::API::*` - REST API endpoints
- `Everything::Application` - Core application logic
- `Everything::Security::*` - Authentication/authorization
- `Everything::Node::*` - Business logic

### Coverage Goals
- **API modules**: >80% (security-critical)
- **Core business logic**: >60% (reliability)
- **Legacy Delegation**: >40% (gradual improvement)
- **Overall project**: >70% (long-term goal after PSGI migration)

### To Increase Coverage
1. Add more mock-based API tests (see `t/060_*.t` for examples)
2. Add unit tests for `Everything::Node::*` classes
3. Test edge cases and error paths
4. Add integration tests for `Everything::Application` methods

See [docs/code-coverage.md](../docs/code-coverage.md) for detailed coverage strategy.

---

**Note**: This report is auto-generated by `tools/generate-coverage-badges.sh`
PERLMD2

        # Clean up intermediate text file
        rm -f "$COVERAGE_DIR/PERL-MODULE-COVERAGE.txt"
    fi
fi

# Generate React module coverage report (from Jest if available)
if [ -f "$PROJECT_ROOT/coverage/react/coverage-summary.json" ]; then
    echo "Generating detailed React module coverage report..."

    cat > "$COVERAGE_DIR/REACT-MODULE-COVERAGE.md" <<REACTMD
# React Module Coverage Report

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')

This report shows test coverage for each React component and module.

## Coverage by Component

| Component | Statements | Branches | Functions | Lines |
|-----------|-----------|----------|-----------|-------|
REACTMD

    # Parse Jest coverage-summary.json and convert to markdown
    jq -r '
        to_entries |
        map(select(.key != "total")) |
        map("| \(.key) | \(.value.statements.pct)% | \(.value.branches.pct)% | \(.value.functions.pct)% | \(.value.lines.pct)% |") |
        .[]
    ' "$PROJECT_ROOT/coverage/react/coverage-summary.json" >> "$COVERAGE_DIR/REACT-MODULE-COVERAGE.md" 2>/dev/null || true

    # Add total line
    jq -r '
        .total |
        "| **Total** | **\(.statements.pct)%** | **\(.branches.pct)%** | **\(.functions.pct)%** | **\(.lines.pct)%** |"
    ' "$PROJECT_ROOT/coverage/react/coverage-summary.json" >> "$COVERAGE_DIR/REACT-MODULE-COVERAGE.md" 2>/dev/null || true

    cat >> "$COVERAGE_DIR/REACT-MODULE-COVERAGE.md" <<'REACTMD2'

## How to Improve Coverage

### High Priority Components (Target: >80%)
- Document components (`react/components/Documents/`)
- Nodelet components (`react/components/Nodelets/`)
- Core UI components (forms, modals, etc.)

### Coverage Goals
- **Document components**: >80% (user-facing)
- **Nodelet components**: >80% (high visibility)
- **Utility functions**: >90% (reusable code)
- **Overall project**: >80% (industry standard)

### To Increase Coverage
1. Add unit tests using `@testing-library/react`
2. Test user interactions (clicks, form submissions)
3. Test error states and edge cases
4. Add snapshot tests for visual regression

Example test:
```javascript
import { render, screen, fireEvent } from '@testing-library/react';
import MyComponent from './MyComponent';

test('renders and handles click', () => {
  render(<MyComponent />);
  const button = screen.getByRole('button');
  fireEvent.click(button);
  expect(screen.getByText('Clicked!')).toBeInTheDocument();
});
```

See [React Testing Library docs](https://testing-library.com/react) for more examples.

---

**Note**: This report is auto-generated by `tools/generate-coverage-badges.sh`
REACTMD2
fi

# Generate coverage summary document
echo "Generating coverage summary..."
cat > "$COVERAGE_DIR/COVERAGE-SUMMARY.md" <<EOF
# Everything2 Code Coverage Summary

**Last Updated**: $(date '+%Y-%m-%d %H:%M:%S')

## Overall Coverage

| Language | Coverage | Status |
|----------|----------|--------|
| ![Perl Coverage](badges/perl-coverage.svg) | ${PERL_COVERAGE}% | $([ $(echo "$PERL_COVERAGE > 60" | bc -l) -eq 1 ] && echo "✅ Good" || echo "⚠️ Needs Improvement") |
| ![React Coverage](badges/react-coverage.svg) | ${REACT_COVERAGE}% | $([ $(echo "$REACT_COVERAGE > 60" | bc -l) -eq 1 ] && echo "✅ Good" || echo "⚠️ Needs Improvement") |

## Perl Coverage Details

**Total Statement Coverage**: ${PERL_COVERAGE}%

Coverage data tracked from mock-based API tests. See [code-coverage.md](../docs/code-coverage.md) for full details.

📊 **[View Detailed Perl Module Coverage Report](PERL-MODULE-COVERAGE.md)** - Module-by-module breakdown

**To regenerate coverage**:
\`\`\`bash
./tools/coverage.sh              # Run full test suite with coverage
./tools/generate-coverage-badges.sh  # Update badges and reports
\`\`\`

## React Coverage Details

**Total Line Coverage**: ${REACT_COVERAGE}%

Coverage data from Jest test suite.

📊 **[View Detailed React Module Coverage Report](REACT-MODULE-COVERAGE.md)** - Component-by-component breakdown

**To regenerate coverage**:
\`\`\`bash
npm test -- --coverage           # Run Jest with coverage
./tools/generate-coverage-badges.sh  # Update badges and reports
\`\`\`

## Coverage Goals

### Current (Dec 2025)
- ✅ Perl: ${PERL_COVERAGE}% (mock-based tests working)
- ✅ React: ${REACT_COVERAGE}% (Jest infrastructure ready)

### Short-term Goals (Q1 2026)
- 🎯 Perl: 40% (comprehensive API testing)
- 🎯 React: 60% (component test coverage)

### Long-term Goals (2026)
- 🎯 Perl: 70% (after PSGI migration enables full coverage)
- 🎯 React: 80% (full component coverage)

## How Coverage Works

### Perl Coverage (Devel::Cover)
- **Mock-based tests**: ✅ Coverage tracked successfully
- **Integration tests**: ✅ Coverage tracked for test-loaded modules
- **Request handlers**: ⏳ Limited coverage (mod_perl architecture)
- **Full coverage**: Requires PSGI/Plack migration (Phase 7)

### React Coverage (Jest)
- **Unit tests**: Coverage tracked via Istanbul/NYC
- **Component tests**: @testing-library/react integration
- **Snapshot tests**: Coverage for render paths

## Recent Coverage Changes

Generated automatically during \`./docker/devbuild.sh\` runs (when not using \`--skip-tests\`).

See \`coverage/html/coverage.html\` for detailed Perl coverage report.
See \`coverage/react/lcov-report/index.html\` for detailed React coverage report.

---

**Note**: This document is auto-generated by \`tools/generate-coverage-badges.sh\`
EOF

echo ""
echo "========================================="
echo "Coverage badges generated!"
echo "========================================="
echo "Perl Coverage: ${PERL_COVERAGE}%"
echo "React Coverage: ${REACT_COVERAGE}%"
echo ""
echo "Badges saved to: $BADGE_DIR/"
echo "Summary saved to: $COVERAGE_DIR/COVERAGE-SUMMARY.md"
echo "========================================="
