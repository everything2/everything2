#!/usr/bin/perl -w
#
# Unit test for Everything::Cron::Schedule -- the declarative cron schedule for
# the in-webhead cron runner (docs/cron-sidecar-design.md). Pure logic: no DB,
# no initEverything, no clock dependence (all times are passed in), so it runs
# standalone and fast. Pins the due()/prev_fire timing and the per-job timeouts
# (the active anti-wedge mechanism) so a regression in either is caught.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything::Cron::Schedule;

my $s = Everything::Cron::Schedule->new;

# --- registry shape -----------------------------------------------------------
my @names = map { $_->{name} } @{ $s->entries };
is( scalar(@names), 6, 'six jobs registered on the sidecar' );
# NB: writeup-reaper was retired in #3070cb0ec ("Retires the node row series of
# documents") -- it ran the legacy "node row" oppressor_superdoc MASSACRE path,
# fully replaced by the draft system (unpublish -> draft, publication_status=removed).
# NB: generate-sitemap is deliberately NOT on the sidecar -- it is a heavy ~50min/~1M-node
# daily batch that no-ops on the resource-shared webhead, so it runs as a dedicated Fargate
# task via its always-ENABLED EventBridge rule (CronGenerateSitemapRule in CloudFormation).
for my $n (qw(datastash refresh-rooms datastash-lengthy iqm-recalc
              clean-old-rooms chatterbox-cleanup)) {
    ok( $s->entry($n), "job '$n' present" );
}
ok( !$s->entry('generate-sitemap'),
    'generate-sitemap is NOT on the sidecar (runs as a dedicated EventBridge task)' );

# Every job MUST carry a positive timeout -- without it a hung job starves the
# sequential runner forever. This is a hard invariant.
for my $e ( @{ $s->entries } ) {
    ok( $e->{timeout} && $e->{timeout} > 0, "job '$e->{name}' has a positive timeout ($e->{timeout}s)" );
    ok( $e->{argv} && @{ $e->{argv} }, "job '$e->{name}' has an argv to exec" );
}

# Timeouts must exceed the expected cadence enough to not false-kill, but the
# frequent ones stay tight. Spot-check datastash (avg 172s observed) -> 600s.
is( $s->entry('datastash')->{timeout}, 600, 'datastash timeout is 600s (>3x observed avg runtime)' );

# --- rate() due() -------------------------------------------------------------
my $now = 1781018349;    # fixed reference epoch
my $ds  = $s->entry('datastash');    # interval 120

ok(  $s->due( $ds, $now, $now - 130 ), 'datastash due when 130s since last run (>120 interval)' );
ok( !$s->due( $ds, $now, $now - 100 ), 'datastash NOT due when only 100s elapsed' );
ok(  $s->due( $ds, $now, $now - 120 ), 'datastash due exactly at the interval boundary' );
ok(  $s->due( $ds, $now, 0 ),          'datastash due when never run (last_run=0)' );

my $daily = $s->entry('iqm-recalc');    # rate interval 86400
ok( !$s->due( $daily, $now, $now - 3600 ),  'daily rate job not due after 1h' );
ok(  $s->due( $daily, $now, $now - 90000 ), 'daily rate job due after >24h' );

# --- cron() prev_fire + due() -------------------------------------------------
# '50 * * * *' fires at HH:50 every hour. Assert structural properties rather
# than TZ-fragile absolute epochs.
my $cb = $s->entry('chatterbox-cleanup');
my $pf = $s->prev_fire( $cb->{cron}, $now );
my ( $pf_min ) = ( gmtime $pf )[1];
is( $pf_min, 50, "chatterbox prev_fire lands on minute :50" );
ok( $pf <= $now,            'chatterbox prev_fire is in the past' );
ok( $now - $pf < 3600,      'chatterbox prev_fire is within the last hour' );
ok(  $s->due( $cb, $now, $pf - 1 ), 'chatterbox due when last run predates the fire' );
ok( !$s->due( $cb, $now, $pf + 1 ), 'chatterbox NOT due when last run is after the fire' );

# Daily '0 0 * * *' fires at 00:00 UTC -- test the cron parser directly (generate-sitemap
# is no longer a registry entry; this is the schedule CronGenerateSitemapRule uses in CF).
my $smf = $s->prev_fire( '0 0 * * *', $now );
my ( $sm_min, $sm_hour ) = ( gmtime $smf )[ 1, 2 ];
is( $sm_min,  0, 'midnight-daily prev_fire minute is 0' );
is( $sm_hour, 0, 'midnight-daily prev_fire hour is 0 (midnight UTC)' );
ok( $now - $smf < 86400, 'midnight-daily prev_fire within the last day' );

# --- expected_period ----------------------------------------------------------
is( $s->expected_period($ds), 120,   'expected_period of a rate job is its interval' );
is( $s->expected_period($cb), 3600,  'expected_period of an hourly cron job is 3600' );
is( $s->expected_period($daily), 86400, 'expected_period of a daily rate job is 86400' );

done_testing();
