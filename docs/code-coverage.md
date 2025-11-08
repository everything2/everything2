# Code Coverage for Everything2

## Overview

This directory contains tooling for measuring and tracking code coverage across the Everything2 Perl codebase using [Devel::Cover](https://metacpan.org/pod/Devel::Cover).

## ⚠️ Current Limitation

**The coverage infrastructure is currently limited by the mod_perl architecture.**

Most E2 tests make HTTP requests to the Apache/mod_perl server running in the container. Since the application code runs in a separate Apache process, Devel::Cover cannot instrument it. Coverage currently only tracks:
- Test runner code (t/run.pl)
- Code executed directly in test processes

**To get full application coverage, we need to migrate to PSGI/Plack** (see [Priority 8 in modernization-priorities.md](../docs/modernization-priorities.md#priority-8-psgiplack-migration-)). PSGI enables in-process testing where the application is loaded directly in the test process, allowing full Devel::Cover instrumentation.

**Status:** Infrastructure ready, blocked by architecture. Use for tracking test-loaded modules only until PSGI migration is complete.

## Quick Start

```bash
# Run tests with coverage tracking
./tools/coverage.sh

# View HTML report
open coverage/html/coverage.html

# Clean coverage data
./tools/coverage.sh clean
```

**Note:** Devel::Cover is already included in the vendored dependencies (`vendor/` directory). If you get an error about a missing module, rebuild the Docker container with `./docker/devbuild.sh`.

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

## Integration with CI/CD

### GitHub Actions (Future)

```yaml
- name: Run tests with coverage
  run: ./tools/coverage.sh

- name: Check coverage threshold
  run: |
    docker exec e2devapp \
      cover -report text -coverage_threshold 70
```

### Coverage Badges

After implementing automated coverage tracking, add a badge to README.md:

```markdown
![Coverage](https://img.shields.io/badge/coverage-XX%25-green)
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
  coverage.sh           # Main coverage script

docs/
  code-coverage.md      # This file

coverage/               # Generated coverage data (git-ignored)
  cover_db/            # Raw coverage database
  html/                # HTML coverage reports
    coverage.html      # Main report page
```

## Further Reading

- [Devel::Cover Documentation](https://metacpan.org/pod/Devel::Cover)
- [Devel::Cover Tutorial](https://perlmaven.com/code-coverage-with-devel-cover)
- [Test::More](https://metacpan.org/pod/Test::More) - Test framework
- [Everything2 Testing Strategy](../docs/quick-reference.md#-testing-strategy)
