#!/usr/bin/perl -w
#
# Integration test for Everything::Cron::State -- the persistence layer for the
# in-webhead cron runner. Exercises the real cron_state / cron_leader tables in
# the dev DB (so it runs in-container after a devbuild bakes the nodepack tables;
# it skips cleanly outside the dev environment). Verifies the upsert writers and
# the UNIX_TIMESTAMP snapshot that feeds Everything::Cron::Health.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;
use Everything::Cron::State;

initEverything 'everything';
unless ( $APP->inDevEnvironment() ) {
    plan skip_all => "Not in the development environment";
    exit;
}

my $JOB   = 'test-cron-state';
my $state = Everything::Cron::State->new;

# Clean slate for our test row (leave real rows / the shared leader row alone).
$DB->sqlDelete( 'cron_state', "job = " . $DB->quote($JOB) );

# --- mark_started -------------------------------------------------------------
$state->mark_started( $JOB, 4242 );
my $s = $state->snapshot->{jobs}{$JOB};
ok( $s, 'mark_started created the job row (lazy insert)' );
is( $s->{status}, 'running', 'status is running' );
is( $s->{pid},    4242,      'pid recorded' );
ok( $s->{started_at} && abs( time() - $s->{started_at} ) < 60, 'started_at is a recent epoch' );
ok( !$s->{last_success}, 'no last_success yet' );

# --- mark_finished ok ---------------------------------------------------------
$state->mark_finished( $JOB, 'ok', duration_ms => 1500, output_tail => 'done' );
$s = $state->snapshot->{jobs}{$JOB};
is( $s->{status},               'ok',  'status ok after success' );
is( $s->{consecutive_failures}, 0,     'failure streak zero' );
is( $s->{duration_ms},          1500,  'duration recorded' );
is( $s->{last_output_tail},     'done','output tail recorded' );
ok( $s->{last_success} && abs( time() - $s->{last_success} ) < 60, 'last_success stamped' );
ok( !defined $s->{pid}, 'pid cleared when not running' );

# --- failures increment the streak; last_success is preserved -----------------
my $prev_success = $s->{last_success};
$state->mark_finished( $JOB, 'fail' );
is( $state->snapshot->{jobs}{$JOB}{consecutive_failures}, 1, 'first failure -> streak 1' );
$state->mark_finished( $JOB, 'fail' );
$s = $state->snapshot->{jobs}{$JOB};
is( $s->{consecutive_failures}, 2,            'second failure -> streak 2' );
is( $s->{last_success},         $prev_success,'last_success unchanged across failures' );
is( $s->{status},               'fail',       'status reflects the failure' );

# --- a success resets the streak ----------------------------------------------
$state->mark_finished( $JOB, 'ok' );
is( $state->snapshot->{jobs}{$JOB}{consecutive_failures}, 0, 'success resets the streak' );

# --- output tail is bounded to the column width -------------------------------
$state->mark_finished( $JOB, 'ok', output_tail => ( 'x' x 5000 ) );
ok( length( $state->snapshot->{jobs}{$JOB}{last_output_tail} ) <= 2000,
    'output tail truncated to <= 2000 chars' );

# --- leader heartbeat ---------------------------------------------------------
$state->heartbeat_leader;
my $leader = $state->snapshot->{leader};
ok( $leader->{heartbeat} && abs( time() - $leader->{heartbeat} ) < 60,
    'leader heartbeat is a recent epoch' );
ok( $leader->{host}, 'leader host recorded' );

# cleanup
$DB->sqlDelete( 'cron_state', "job = " . $DB->quote($JOB) );

done_testing();
