# Perl Test Parallelization

**Date**: 2025-11-24
**Session**: 10

## Overview

Implemented parallel test execution for Everything2's Perl test suite, reducing execution time while avoiding race conditions through intelligent test grouping.

## Results

### Performance
- **Time**: ~47 seconds (parallelized) vs ~2-3 minutes (sequential)
- **Speedup**: ~3-4x faster
- **Tests**: 1243 tests across 44 test files
- **Success Rate**: 100% (all tests passing)

### Configuration
- **Parallel Jobs**: Auto-detected (cores - 2)
- **System**: 16 cores → 14 parallel jobs
- **Reserves**: 2 cores for Apache and MySQL
- **Override**: Set `TEST_JOBS` env var to customize

## Implementation

### Test Grouping Strategy

Tests are separated into two groups:

1. **Serial Tests** (run sequentially):
   - `036_message_opcode.t` - Deletes all public messages
   - `037_chatter_api.t` - Deletes all public chatter
   - These tests modify shared database state and cause race conditions when run concurrently

2. **Parallel Tests** (run concurrently):
   - All other 42 tests
   - Safe to run in parallel as they don't modify shared global state

### Execution Order

```
1. Run 2 serial tests sequentially (jobs=1)
2. Run 42 parallel tests concurrently (jobs=6)
3. Aggregate results and exit with error code if any failures
```

## Technical Details

### TAP::Harness

Changed from `Test::Harness` to `TAP::Harness` for better parallel support:

```perl
use TAP::Harness;

my $harness = TAP::Harness->new({
    jobs => $parallel_jobs,
    verbosity => 1,
    lib => ['/var/libraries/lib/perl5'],
});

my $result = $harness->runtests(@test_files);
```

### CPU Detection

Auto-detects CPU cores using multiple methods:

```perl
sub get_cpu_count {
    # Try nproc first (most reliable)
    my $nproc = `nproc 2>/dev/null`;
    chomp $nproc;
    return int($nproc) if $nproc && $nproc =~ /^\d+$/;

    # Fall back to /proc/cpuinfo
    if (open my $fh, '<', '/proc/cpuinfo') {
        my $count = 0;
        while (<$fh>) {
            $count++ if /^processor\s*:/;
        }
        close $fh;
        return $count if $count > 0;
    }

    # Default to 1 if detection fails
    return 1;
}
```

### Aggressive Parallelization (with Test Grouping)

Since race-prone tests run separately, we can use most available cores:

```perl
# Formula: cores - 2 (leave 2 for Apache and MySQL)
my $num_cores = get_cpu_count();
my $parallel_jobs = $num_cores - 2;
$parallel_jobs = 2 if $parallel_jobs < 2;  # Minimum of 2 jobs
```

**Rationale**:
- Test grouping eliminates race conditions between parallel tests
- Serial tests (2) run first sequentially
- Parallel tests (42) can run concurrently without interference
- Leave 2 cores for Apache and MySQL background processes
- Apache MPM prefork has 150 workers (more than sufficient)
- Database I/O becomes the bottleneck, not CPU

## Apache Configuration

Verified Apache MPM prefork settings are sufficient:

```
StartServers            5
MinSpareServers         5
MaxSpareServers         10
MaxRequestWorkers       150    # More than enough for 6 parallel tests
MaxConnectionsPerChild  0
```

## Usage

### Default (auto-detect cores)
```bash
./docker/run-tests.sh
```

### Custom parallel jobs
```bash
TEST_JOBS=4 ./docker/run-tests.sh
```

### Serial only (troubleshooting)
```bash
TEST_JOBS=1 ./docker/run-tests.sh
```

## Race Condition Detection

To identify tests that need serial execution:

1. Run tests in parallel and note failures
2. Check if test passes when run alone: `docker exec e2devapp perl t/XXX_test.t`
3. Look for global database operations: `grep -n "sqlDelete" t/XXX_test.t`
4. Add to `%serial_tests` hash in `t/run.pl`

### Common Race Condition Patterns

Tests that should run serially:
- Delete all records from shared tables (`for_user=0`, global settings)
- Modify system-wide configuration
- Test admin/god-level operations that affect other users
- Clear caches or reset global state

Tests safe for parallel execution:
- Create/read/update/delete specific test records
- Use unique identifiers (user IDs, timestamps, random strings)
- Operate on isolated data
- Read-only tests

## Future Improvements

### Test Isolation
- Use transactions that rollback (requires InnoDB tables)
- Create test-specific data with unique prefixes
- Mock database operations for unit tests
- Use separate test database per parallel job

### Performance
- Profile tests to identify slow tests
- Run slow tests first (TAP::Harness does this automatically)
- Cache database setup between test runs
- Optimize database queries in tests

### Monitoring
- Track test execution time over time
- Alert on flaky tests (pass/fail inconsistency)
- Measure parallelization efficiency

## Smoke Test Parallelization

The smoke test has also been parallelized for faster pre-flight checks.

### Performance
- **Before**: ~20-30 seconds (sequential, 159 documents)
- **After**: ~4 seconds (parallelized, 14 workers)
- **Speedup**: ~5-7x faster

### Implementation

**Thread Pool Pattern**:
```ruby
def test_pages_parallel(docs, num_workers)
  require 'thread'

  queue = Queue.new
  docs.each { |doc| queue << doc }

  results = []
  results_mutex = Mutex.new
  print_mutex = Mutex.new

  workers = (1..num_workers).map do
    Thread.new do
      until queue.empty?
        doc = queue.pop(true) rescue break
        result = test_page_quiet(doc, print_mutex)
        results_mutex.synchronize { results << result }
      end
    end
  end

  workers.each(&:join)
  results
end
```

**Key Features**:
- Thread-safe output (mutex-protected printing)
- Thread-safe result collection
- Auto-detects CPU cores (same formula as Perl tests)
- Uses 14 workers on 16-core system
- Tests 159 special documents in ~4 seconds

## Test Output Verbosity

Test output has been reduced for cleaner builds:

**Perl Tests**: Changed `verbosity => 1` to `verbosity => -1`
- **Before**: Shows every individual test assertion
- **After**: Shows only file names and pass/fail summary
- **Benefit**: Cleaner output, easier to spot failures

Example output:
```
--- Running 2 tests serially (shared database state) ---
/var/everything/t/036_message_opcode.t .. ok
/var/everything/t/037_chatter_api.t ..... ok
Result: PASS

--- Running 42 tests in parallel ---
/var/everything/t/001_api_routing.t ........ ok
/var/everything/t/002_sessions_api.t ....... ok
[...]
Result: PASS
```

## Parallel Test Runner (Session 10)

**NEW**: Unified test runner that executes smoke, perl, and react tests in parallel.

**Script**: [tools/parallel-test.sh](../tools/parallel-test.sh)

### Features

- **Parallel Execution**: Smoke+Perl tests run concurrently with React tests
- **Progress Indicators**: Animated spinners show test progress
- **Color-Coded Output**: Green for pass, red for fail, blue for section headers
- **Smart Summaries**: Shows only relevant output, full logs available on failure
- **Integrated into Build**: Used automatically by `devbuild.sh`

### Performance

**Before (Serial)**:
```
Smoke tests (4s) → Perl tests (48s) → React tests (3.3s) = 55.3s total
```

**After (Parallel)**:
```
max(Smoke+Perl: 52s, React: 3.3s) = 52s total
```

**Savings**: ~3.3s (6% faster, better UX)

### Usage

**Standalone**:
```bash
./tools/parallel-test.sh
```

**Integrated (automatic)**:
```bash
./docker/devbuild.sh  # Uses parallel-test.sh
```

### Output Format

```
╔════════════════════════════════════════════════════════════╗
║     Everything2 Parallel Test Runner                      ║
╚════════════════════════════════════════════════════════════╝

Running Perl and React tests in parallel...

Perl/Smoke: [⠋]  React: [⠙]

═══════════════════════════ Results ═══════════════════════════

Perl Tests (Smoke + Unit):
✓ PASSED
Running tests with 14 parallel jobs (detected 16 cores)
Result: PASS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

React Tests:
✓ PASSED
Test Suites: 25 passed, 25 total
Tests:       445 passed, 445 total
Time:        3.266 s

═══════════════════════════════════════════════════════════════

✓ All Tests Passed!
```

### Exit Code Bug Fix (Session 10)

**Issue**: Original implementation used `grep` to filter test output, but `grep` returns exit code 1 when it finds no matches. This caused false failures even when tests passed.

**Original Code** (buggy):
```bash
run_react_tests() {
  {
    echo "=== Running React Tests ==="
    if npm test -- --passWithNoTests 2>&1 | grep -E '(PASS|FAIL|Test Suites|Tests:)'; then
      echo -e "${GREEN}✓ React tests passed${NC}"
    else
      echo -e "${RED}✗ React tests failed${NC}"
      exit 1
    fi
  } > "$REACT_OUTPUT" 2>&1
}
```

**Problem**: If `grep` doesn't find matching patterns, it returns exit code 1, making the `if` statement fail regardless of actual test results.

**Fixed Code**:
```bash
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
```

**Solution**: Capture the actual exit code from the test command using `$?`, then check that value instead of relying on `grep`'s exit code.

**Lesson**: When processing command output in Bash, separate the success/failure logic from the output filtering logic. Use `grep` only for display, not for determining pass/fail status.

## Related Files

- [t/run.pl](../t/run.pl) - Perl test runner script (parallelized)
- [docker/run-tests.sh](../docker/run-tests.sh) - Perl test execution wrapper
- [docker/devbuild.sh](../docker/devbuild.sh) - Build script (uses parallel-test.sh)
- [tools/smoke-test.rb](../tools/smoke-test.rb) - Parallel smoke test (14 workers)
- [tools/parallel-test.sh](../tools/parallel-test.sh) - **NEW**: Unified parallel test runner

## References

- TAP::Harness documentation: https://metacpan.org/pod/TAP::Harness
- Test::Harness (legacy): https://metacpan.org/pod/Test::Harness
- Apache MPM prefork: https://httpd.apache.org/docs/2.4/mod/prefork.html
- Ruby Thread documentation: https://ruby-doc.org/core/Thread.html
