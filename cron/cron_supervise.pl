#!/usr/bin/perl

# cron_supervise.pl -- background supervisor for a single DETACHED cron job
# (Everything::Cron::Schedule entries flagged detached => 1, e.g. generate-sitemap).
#
# The in-webhead cron leader (Everything::Cron::Runner) forks+execs THIS script and
# returns immediately, so a heavy ~50min batch job does NOT block the ~1min tick or
# pin the GET_LOCK for its whole runtime (which starved the frequent jobs and tripped
# the wedge alarm). The leader has already marked the job 'running' in cron_state; we
# run it, enforce its wall-clock timeout (TERM -> grace -> KILL), and record the
# result (ok | fail | timeout) via Everything::Cron::State->mark_finished -- on our
# OWN $DB connection (a fresh initEverything), never the leader's.
#
# Usage (built by Everything::Cron::Runner::_supervise_argv):
#   cron_supervise.pl <job_name> <timeout_secs> -- <job argv...>

use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use POSIX qw(:sys_wait_h);
use Time::HiRes ();
use Everything;
use Everything::Cron::State;

my $KILL_GRACE = 5;    # seconds between TERM and KILL on timeout

my ( $name, $timeout, @rest ) = @ARGV;
shift @rest if @rest && $rest[0] eq '--';
die "usage: cron_supervise.pl <name> <timeout> -- <argv...>\n"
    unless defined $name && length $name && $timeout && $timeout =~ /\A\d+\z/ && @rest;

initEverything 'everything';
my $state = Everything::Cron::State->new;

my $start = Time::HiRes::time();

my $pid = fork;
if ( !defined $pid ) {
    # Couldn't even start the job -- record a failure so it isn't stuck 'running'.
    print STDERR "[cron-supervise] fork failed for $name: $!\n";
    $state->mark_finished( $name, 'fail', duration_ms => 0 );
    exit 1;
}
if ( $pid == 0 ) {
    exec { $rest[0] } @rest;
    print STDERR "[cron-supervise] exec failed for $name: $!\n";
    POSIX::_exit(127);
}

# Wait for the job, enforcing the timeout. No GET_LOCK to keep alive here (the leader
# released it the moment it handed us the job), so this is a plain bounded wait.
my $deadline  = time + $timeout;
my $timed_out = 0;
my $exit      = 0;
while (1) {
    my $reaped = waitpid( $pid, WNOHANG );
    if ( $reaped == $pid ) { $exit = $? >> 8; last; }
    if ( $reaped == -1 )   { $exit = 0;       last; }    # already gone
    if ( time >= $deadline ) {
        $timed_out = 1;
        print STDERR "[cron-supervise] TIMEOUT -- $name pid $pid exceeded ${timeout}s\n";
        kill 'TERM', $pid;
        my $grace = time + $KILL_GRACE;
        while ( time < $grace ) { last if waitpid( $pid, WNOHANG ) == $pid; sleep 1; }
        if ( kill 0, $pid ) { kill 'KILL', $pid; waitpid( $pid, 0 ); }
        last;
    }
    sleep 1;
}

my $dur_ms = int( ( Time::HiRes::time() - $start ) * 1000 );
my $result = $timed_out ? 'timeout' : ( $exit == 0 ? 'ok' : 'fail' );
$state->mark_finished( $name, $result, duration_ms => $dur_ms );
print STDERR "[cron-supervise] $name finished: $result (${dur_ms}ms)\n";
exit 0;
