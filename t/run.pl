#!/usr/bin/perl -w

use lib qw(/var/libraries/lib/perl5);
use strict;
use File::Basename;
use Cwd 'abs_path';
use TAP::Harness;
use File::Find;

# Set alternate log location for test runner to avoid conflicts with Apache process
$ENV{E2_DEV_LOG} = "/tmp/test-runner.log";

# Auto-detect number of CPU cores for parallel testing
# Use most available cores since race-prone tests run separately in serial group
# Formula: cores - 2 (leave 2 for Apache and MySQL)
my $num_cores = get_cpu_count();
my $parallel_jobs = $num_cores - 2;
$parallel_jobs = 2 if $parallel_jobs < 2;  # Minimum of 2 jobs
$parallel_jobs = $ENV{TEST_JOBS} if defined $ENV{TEST_JOBS};  # Allow override via env var

print "Running tests with $parallel_jobs parallel jobs (detected $num_cores cores)\n";

my $testfiles;
my $dirname = dirname(abs_path($0));
my $wanted = sub {$testfiles->{$_}=1 if /\.t$/ and not /\legacy\//};

find({wanted => $wanted, no_chdir => 1}, $dirname);

# Tests that must run sequentially due to shared database state
# These tests delete/modify global data (public messages, etc.) and cause race conditions
# Also includes tests that share user accounts (normaluser1, normaluser2) to avoid session conflicts
my %serial_tests = (
    "$dirname/008_e2nodes.t" => 1,        # Uses normaluser1/normaluser2, creates/deletes nodes
    "$dirname/009_writeups.t" => 1,       # Uses normaluser1/normaluser2, creates/deletes writeups
    "$dirname/042_message_opcode.t" => 1, # Modifies message table
    "$dirname/041_online_only_messages.t" => 1, # Modifies message table, creates usergroups
    "$dirname/043_chatter_api.t" => 1,    # Modifies message table (public chatter)
    "$dirname/044_message_outbox.t" => 1, # Modifies message table (outbox entries)
    "$dirname/046_message_ignores_delivery.t" => 1, # Modifies messageignore table (root/guest user)
    "$dirname/047_message_block_notifications.t" => 1, # Modifies messageignore table (root/guest user)
);

# Separate serial and parallel tests
my @serial = grep { $serial_tests{$_} } sort {$a cmp $b} keys %$testfiles;
my @parallel = grep { !$serial_tests{$_} } sort {$a cmp $b} keys %$testfiles;

my $total_errors = 0;

# Run serial tests first (sequentially)
if (@serial) {
    print "\n--- Running " . scalar(@serial) . " tests serially (shared database state) ---\n";
    my $serial_harness = TAP::Harness->new({
        jobs => 1,
        verbosity => -1,  # -1 = quiet (only show summary), 0 = normal, 1 = verbose
        lib => ['/var/libraries/lib/perl5'],
    });
    my $serial_result = $serial_harness->runtests(@serial);
    $total_errors += $serial_result->has_errors ? 1 : 0;
}

# Run parallel tests (concurrently)
if (@parallel) {
    print "\n--- Running " . scalar(@parallel) . " tests in parallel ---\n";
    my $parallel_harness = TAP::Harness->new({
        jobs => $parallel_jobs,
        verbosity => -1,  # -1 = quiet (only show summary), 0 = normal, 1 = verbose
        lib => ['/var/libraries/lib/perl5'],
    });
    my $parallel_result = $parallel_harness->runtests(@parallel);
    $total_errors += $parallel_result->has_errors ? 1 : 0;
}

exit($total_errors);

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

