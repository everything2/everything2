# Code Coverage for Everything2

**Last verified: 2026-11-16**

## Overview

Everything2 uses [Devel::Cover](https://metacpan.org/pod/Devel::Cover) for Perl and Jest's built-in coverage for React. Coverage is generated on demand (`./docker/devbuild.sh --coverage` or `./tools/coverage.sh`) and tracked via SVG badges committed under `coverage/badges/`.

## Current Status

| Suite | Coverage | Source |
|-------|----------|--------|
| Perl (statements) | **53.1%** | `coverage/COVERAGE-SUMMARY.md`, last regenerated 2026-06-15 |
| React (lines) | **55.6%** (statements 54.6%, branches 49.8%, functions 45.8%) | measured 2026-11-16 with `npm test -- --coverage`; the committed badge (17.73%, June 2026) is stale until badges are regenerated |

Suite size (2026-11-16): 222 Perl test files (`t/*.t`), 313 Jest suites / 2789 tests.

### History: how coverage started working (Dec 2025)

The migration from legacy HTTP-based tests to mock-based unit tests enabled coverage tracking. The Everything::APIClient module has been removed from the codebase.

### What's Tracked

- ✅ **API Modules** (`Everything::API::*`) - ~24% coverage from mock tests
- ✅ **Application Logic** (`Everything::Application`) - Tracked via unit tests
- ✅ **Node Classes** (`Everything::Node::*`) - Tracked when instantiated in tests
- ✅ **Business Logic** - Any code executed during test runs

### Current Coverage

![Perl Coverage](../coverage/badges/perl-coverage.svg)

**Dec 2025 snapshot (historical)** — from just 6 mock-based API tests (~24% overall):
- `Everything::API::e2nodes`: 100%
- `Everything::API::users`: 100%
- `Everything::API::writeups`: 81.2%
- `Everything::API::developervars`: 85.7%
- `Everything::API::preferences`: 46.1%

See [coverage/COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) for detailed coverage reports.

### Future Coverage

**Full request-path coverage** is now achievable: the PSGI/Plack migration is done and live (as of 2026-06), so request handlers can be exercised directly rather than only through mocks.

## Quick Start

Coverage is **opt-in**: plain `./docker/devbuild.sh` runs tests without coverage. Add `--coverage` to also run `tools/coverage.sh clean`, `tools/coverage.sh` and `tools/generate-coverage-badges.sh`.

### Manual Coverage Commands

```bash
# Run development build with tests, coverage and badge regeneration
./docker/devbuild.sh --coverage

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
1. Clean old coverage data (`rm -rf coverage/` — including the tracked badges/summaries, which `generate-coverage-badges.sh` then recreates)
2. Run Jest with coverage (`npm test -- --coverage --watchAll=false`, output in `coverage/react/`)
3. `docker cp` `t/` and `ecore/` into the `e2devapp` container
4. Run `t/run.pl` under Devel::Cover (ignoring `t/` and `/var/libraries/`)
5. Generate the HTML report and print a text summary

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

### Current (2026-11-16)
- **Perl**: 53.1% (June 2026 snapshot)
- **React**: 55.6% lines

### Short-term Goals (set for Q1 2026)
- ✅ **Perl**: 40% — met
- 🎯 **React**: 60% — close (55.6%)

### Long-term Goals (2026+)
- 🎯 **Perl**: 70% (full request-path coverage, now unblocked — PSGI migration is done/live as of 2026-06)
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

- `t/` - Test files themselves (`-ignore,'^/var/everything/t/'`)
- `/var/libraries/` - CPAN dependencies (`-ignore` / `-ignore_re`)
- React: `react/index.js`, `*.test.js`, `__tests__/`, `__mocks__/` (`collectCoverageFrom` in `jest.config.js`)

## Advanced Usage

### Manual Coverage Run

Inside the Docker container:

```bash
# Run tests with coverage (what tools/coverage.sh does)
perl -I/var/libraries/lib/perl5 -I/var/everything/ecore \
  -MDevel::Cover=-db,/var/everything/coverage/cover_db,-ignore,'^/var/everything/t/',-ignore,'^/var/libraries/',-silent,1 \
  t/run.pl

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
  -I/var/everything/ecore \
  t/012_users_api.t
```

### Merge Multiple Coverage Runs

```bash
# Merge coverage databases
cover -merge_from coverage/cover_db.1 coverage/cover_db.2
```

## Integration with Development Workflow

### Coverage via devbuild (opt-in)

`./docker/devbuild.sh --coverage`, after the normal parallel test run:
1. Runs `tools/coverage.sh clean` then `tools/coverage.sh` (Jest + Devel::Cover)
2. Runs `tools/generate-coverage-badges.sh`, which updates the SVG badges and regenerates `COVERAGE-SUMMARY.md`, `PERL-MODULE-COVERAGE.md`, `REACT-MODULE-COVERAGE.md`

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

### Future: CI Integration (not planned)

Prod builds run on AWS CodeBuild, not GitHub Actions (GHA only runs CodeQL), so the snippet below is illustrative only.

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
1. Run regular tests: `./tools/parallel-test.sh` or `./docker/run-tests.sh`
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
    coverage-summary.json       # Jest json-summary (read by the badge script)
  COVERAGE-SUMMARY.md            # Auto-generated coverage summary (tracked)
  PERL-MODULE-COVERAGE.md        # Per-module Perl breakdown (tracked)
  REACT-MODULE-COVERAGE.md       # Per-component React breakdown (tracked)
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


## Further Reading

- [coverage/COVERAGE-SUMMARY.md](../coverage/COVERAGE-SUMMARY.md) - Current coverage status
- [Devel::Cover Documentation](https://metacpan.org/pod/Devel::Cover)
- [Devel::Cover Tutorial](https://perlmaven.com/code-coverage-with-devel-cover)
- [Test::More](https://metacpan.org/pod/Test::More) - Test framework
- [Everything2 Testing Strategy](quick-reference.md#-testing-strategy)
- [React Testing Guide](react-testing.md)
