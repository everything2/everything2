#!/usr/bin/perl -w
#
# Unit test for Everything::Cron::Health -- the wedge evaluator. Pure logic over
# a passed-in state snapshot + clock, so it runs standalone (no DB). Pins every
# branch of the wedge taxonomy so "can we tell if a cron job is wedged" stays
# answerable: hung, overdue, failing, and leader-stale, plus the healthy path.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything::Cron::Schedule;
use Everything::Cron::Health;

my $sched = Everything::Cron::Schedule->new;
my $h     = Everything::Cron::Health->new( schedule => $sched );
my $now   = 1781018349;

# Build an all-healthy snapshot: fresh leader heartbeat, every job succeeded
# 10s ago. (10s is within overdue_factor*period for every job, incl. datastash.)
sub healthy {
    my %jobs;
    for my $e ( @{ $sched->entries } ) {
        $jobs{ $e->{name} } = {
            status               => 'ok',
            started_at           => $now - 12,
            finished_at          => $now - 10,
            last_success         => $now - 10,
            duration_ms          => 2000,
            consecutive_failures => 0,
            host                 => 'webhead-1',
        };
    }
    return { leader => { heartbeat => $now, host => 'webhead-1' }, jobs => \%jobs };
}

# --- healthy baseline ---------------------------------------------------------
{
    my $v = $h->evaluate( healthy(), $now );
    is( $v->{overall}, 'ok', 'all-healthy snapshot -> overall ok' );
    is( $v->{leader}{state}, 'ok', 'leader reported ok' );
    is_deeply( $v->{wedged},  [], 'nothing wedged' );
    is_deeply( $v->{failing}, [], 'nothing failing' );
    is( $v->{jobs}{datastash}{state}, 'ok', 'datastash ok' );
    like( $v->{summary}, qr/cron ok/, 'summary says ok' );
}

# --- leader stale dominates ---------------------------------------------------
{
    my $st = healthy();
    $st->{leader}{heartbeat} = $now - 600;    # >> leader_stale_secs (90)
    my $v = $h->evaluate( $st, $now );
    is( $v->{overall}, 'down', 'stale leader heartbeat -> subsystem down' );
    is( $v->{leader}{state}, 'stale', 'leader flagged stale' );
    like( $v->{summary}, qr/leader stale/, 'summary calls out stale leader' );
}
{
    my $st = healthy();
    delete $st->{leader};    # no heartbeat row at all
    my $v = $h->evaluate( $st, $now );
    is( $v->{overall}, 'down', 'missing leader heartbeat -> down' );
}

# --- hung job (running past its timeout) -- the loudest per-job signal ---------
{
    my $st  = healthy();
    my $to  = $sched->entry('datastash')->{timeout};    # 600
    $st->{jobs}{datastash} = {
        status => 'running', started_at => $now - ( $to + 30 ), pid => 4242, host => 'webhead-1',
    };
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{datastash}{state}, 'hung', 'job running past timeout -> hung' );
    is( $v->{jobs}{datastash}{pid}, 4242, 'hung verdict carries the pid for the kill/inspect' );
    ok( ( grep { $_ eq 'datastash' } @{ $v->{wedged} } ), 'hung job appears in wedged set' );
    is( $v->{overall}, 'degraded', 'a hung job (fresh leader) -> degraded' );
}

# --- running but within timeout is healthy, NOT wedged ------------------------
{
    my $st = healthy();
    $st->{jobs}{datastash} = { status => 'running', started_at => $now - 5, pid => 99, host => 'webhead-1' };
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{datastash}{state}, 'running', 'in-progress within timeout -> running' );
    is_deeply( $v->{wedged}, [], 'a healthy in-progress job is not wedged' );
    is( $v->{overall}, 'ok', 'overall stays ok' );
}

# --- overdue (no success within period * factor) ------------------------------
{
    my $st = healthy();
    # datastash period 120, factor 2 -> overdue past 240s since last success.
    $st->{jobs}{datastash}{last_success} = $now - 500;
    $st->{jobs}{datastash}{started_at}   = $now - 502;
    $st->{jobs}{datastash}{finished_at}  = $now - 500;
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{datastash}{state}, 'overdue', 'no success within 2x period -> overdue' );
    ok( ( grep { $_ eq 'datastash' } @{ $v->{wedged} } ), 'overdue job appears in wedged set' );
    is( $v->{overall}, 'degraded', 'overdue -> degraded' );
}

# --- never-run job is surfaced as overdue ------------------------------------
{
    my $st = healthy();
    $st->{jobs}{datastash} = { status => 'unknown' };    # no last_success
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{datastash}{state}, 'overdue', 'never-succeeded job -> overdue (surfaced)' );
}

# --- failing (consecutive failures over threshold) ----------------------------
{
    my $st = healthy();
    $st->{jobs}{'refresh-rooms'} = {
        status => 'fail', last_success => $now - 30, consecutive_failures => 3,
    };
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{'refresh-rooms'}{state}, 'failing', '3 consecutive failures -> failing' );
    ok( ( grep { $_ eq 'refresh-rooms' } @{ $v->{failing} } ), 'failing job in failing list' );
    ok( !( grep { $_ eq 'refresh-rooms' } @{ $v->{wedged} } ), 'failing is distinct from wedged' );
    is( $v->{overall}, 'degraded', 'failing -> degraded' );
}

# --- below failure threshold is still ok if recent ----------------------------
{
    my $st = healthy();
    $st->{jobs}{'refresh-rooms'}{consecutive_failures} = 2;    # below threshold 3
    my $v = $h->evaluate( $st, $now );
    is( $v->{jobs}{'refresh-rooms'}{state}, 'ok', '2 failures (recent success) stays ok' );
}

done_testing();
