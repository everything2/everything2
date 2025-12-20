# Code Coverage for Everything2

## Overview

Everything2 uses [Devel::Cover](https://metacpan.org/pod/Devel::Cover) to measure and track code coverage across the Perl codebase. Coverage reports are generated automatically during development builds and tracked via SVG badges.

## ✅ Current Status (Dec 2025)

**Coverage is now working!** The migration from legacy HTTP-based tests to mock-based unit tests has enabled proper code coverage tracking. The Everything::APIClient module has been removed from the codebase.

### What's Tracked

- ✅ **API Modules** (`Everything::API::*`) - ~24% coverage from mock tests
- ✅ **Application Logic** (`Everything::Application`) - Tracked via unit tests
- ✅ **Node Classes** (`Everything::Node::*`) - Tracked when instantiated in tests
- ✅ **Business Logic** - Any code executed during test runs

### Current Coverage

![Perl Coverage](../coverage/badges/perl-coverage.svg)

**From just 6 mock-based API tests**: ~24% overall coverage
- `Everything::API::e2nodes`: 100%
- `Everything::API::users`: 100%
- `Everything::API::writeups`: 81.2%
- `Everything::API::developervars`: 85.7%
- `Everything::API::preferences`: 46.1%

See [coverage/COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) for detailed coverage reports.

### Future Coverage

**Full request handler coverage** still requires PSGI/Plack migration (Phase 7), but current mock-based testing provides excellent coverage of business logic, APIs, and core modules.

## Quick Start

**Coverage runs automatically** during `./docker/devbuild.sh` (unless you use `--skip-tests`).

### Manual Coverage Commands

```bash
# Run development build with tests and coverage (automatic)
./docker/devbuild.sh

# Run tests with coverage manually
./tools/coverage.sh

# Generate coverage badges
./tools/generate-coverage-badges.sh

# View HTML report
open coverage/html/coverage.html

# Clean coverage data
./tools/coverage.sh clean
```

**Coverage badges** are automatically updated and embedded in README.md:
- ![Perl Coverage](../coverage/badges/perl-coverage.svg)
- ![React Coverage](../coverage/badges/react-coverage.svg)

## Usage

### Basic Coverage Run

```bash
./tools/coverage.sh
```

This will:
1. Clean old coverage data
2. Sync code to the Docker container
3. Run all tests with Devel::Cover enabled
4. Generate HTML and text coverage reports
5. Display a summary

### Generate Report Only

If you already have coverage data and just want to regenerate the report:

```bash
./tools/coverage.sh report
```

### Clean Coverage Data

```bash
./tools/coverage.sh clean
```

## Coverage Reports

### HTML Report

The primary coverage report is an interactive HTML interface:

- **Location:** `coverage/html/coverage.html`
- **Features:**
  - Per-file coverage breakdown
  - Line-by-line coverage highlighting
  - Branch coverage analysis
  - Subroutine coverage
  - POD coverage

### Text Summary

A text summary is displayed after each coverage run showing:
- Overall coverage percentage
- Statement coverage
- Branch coverage
- Condition coverage
- Subroutine coverage
- Pod coverage

## Coverage Goals

### Current (Dec 2025)
- ✅ **Perl**: ~24% (6 mock-based API tests)
- ✅ **React**: 0% (Jest infrastructure ready, tests needed)

### Short-term Goals (Q1 2026)
- 🎯 **Perl**: 40% (comprehensive API testing)
- 🎯 **React**: 60% (component test coverage)

### Long-term Goals (2026+)
- 🎯 **Perl**: 70% (after PSGI migration)
- 🎯 **React**: 80% (full component coverage)

### By Module Type

| Module Type | Target Coverage |
|-------------|----------------|
| Security & API modules | >80% |
| Core business logic | >60% |
| Legacy Delegation code | >40% |
| Overall project | >70% |

### Priority Modules

**High Priority (>80%):**
- `Everything::Application` - Core application logic
- `Everything::Security::*` - Authentication/authorization
- `Everything::API::*` - Public API endpoints
- `Everything::dataprovider::*` - Data access layer

**Medium Priority (>60%):**
- `Everything::Node::*` - Business logic
- `Everything::NodeBase` - Database operations
- `Everything::HTML` - Rendering
- `Everything::Request` - Request routing

## Exclusions

The following are excluded from coverage analysis:

- `t/` - Test files themselves
- `vendor/` - Third-party dependencies
- Moose-generated code (attributes, etc.)
- Legacy eval'd database code

## Advanced Usage

### Manual Coverage Run

Inside the Docker container:

```bash
# Run tests with coverage
perl -MDevel::Cover=-db,coverage/cover_db,-ignore,'^t/',-ignore,'^vendor/' t/run.pl

# Generate HTML report
cover -report html -outputdir coverage/html

# Generate text report
cover -report text

# Check against threshold
cover -report text -coverage_threshold 70
```

### Coverage for Specific Tests

```bash
# Run specific test with coverage
docker exec e2devapp \
  perl -MDevel::Cover=-db,/var/everything/coverage/cover_db \
  -I/var/libraries/lib/perl5 \
  t/012_sql_injection_fixes.t
```

### Merge Multiple Coverage Runs

```bash
# Merge coverage databases
cover -merge_from coverage/cover_db.1 coverage/cover_db.2
```

## Integration with Development Workflow

### Automated Coverage (Current)

Coverage is **automatically generated** during `./docker/devbuild.sh`:
1. Tests run in parallel
2. Coverage data is collected via Devel::Cover
3. Coverage reports are generated
4. SVG badges are updated
5. COVERAGE-SUMMARY.md is regenerated

### Coverage Badges (Active)

Coverage badges are embedded in README.md and auto-updated:

```markdown
![Perl Coverage](coverage/badges/perl-coverage.svg)
![React Coverage](coverage/badges/react-coverage.svg)
```

**Badge Colors:**
- 🔴 Red: <20%
- 🟠 Orange: 20-40%
- 🟡 Yellow: 40-60%
- 🟢 Yellow-green: 60-80%
- 💚 Green: ≥80%

### Future: GitHub Actions Integration

```yaml
- name: Run tests with coverage
  run: ./docker/devbuild.sh

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/lcov.info
```

## Troubleshooting

### "Container not running" Error

Ensure the Docker container is running:
```bash
./docker/devbuild.sh
```

### Slow Coverage Runs

Coverage adds overhead. For faster iteration:
1. Run regular tests: `./docker/run-tests.sh`
2. Run coverage periodically or before commits

### Out of Memory

Large codebases may require more memory. Increase Docker memory allocation in Docker Desktop settings.

## Files and Directories

```
tools/
  coverage.sh                    # Main coverage script
  generate-coverage-badges.sh    # Badge generation script

docs/
  code-coverage.md               # This file

coverage/                        # Generated coverage data
  badges/                        # SVG coverage badges (tracked in git)
    perl-coverage.svg           # Perl coverage badge
    react-coverage.svg          # React coverage badge
  cover_db/                      # Raw Perl coverage database (git-ignored)
  html/                          # HTML coverage reports (git-ignored)
    coverage.html               # Main Perl report page
  react/                         # React coverage reports (git-ignored)
    lcov-report/                # Jest HTML coverage
  COVERAGE-SUMMARY.md            # Auto-generated coverage summary
```

## Mock-Based Testing Enables Coverage

The key breakthrough was **migrating from legacy HTTP-based tests to mock-based unit tests**:

### Before (Legacy HTTP Tests)
```perl
# Tests made HTTP requests to Apache/mod_perl server
# Coverage couldn't track code execution in separate process
use Everything::APIClient;  # ❌ Module removed
my $client = Everything::APIClient->new();
my $result = $client->get('/api/writeups/123');  # ❌ No coverage
```

### After (Mock-Based Tests)
```perl
# Tests directly instantiate and test API classes
# Coverage tracks all code execution
use Everything::API::writeups;
my $api = Everything::API::writeups->new();
my $result = $api->get_writeup($mock_request);  # ✅ Full coverage!
```

**Result**: From 0% coverage to 24% coverage with just 6 API tests!

**Cleanup Complete**: All legacy HTTP-based tests and the APIClient module have been removed.

See [api-test-conversion-summary.md](api-test-conversion-summary.md) for migration details.

## Further Reading

- [coverage/COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) - Current coverage status
- [Devel::Cover Documentation](https://metacpan.org/pod/Devel::Cover)
- [Devel::Cover Tutorial](https://perlmaven.com/code-coverage-with-devel-cover)
- [Test::More](https://metacpan.org/pod/Test::More) - Test framework
- [Everything2 Testing Strategy](quick-reference.md#-testing-strategy)
- [API Test Conversion Summary](api-test-conversion-summary.md) - How we enabled coverage
