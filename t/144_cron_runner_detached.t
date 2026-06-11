#!/usr/bin/perl -w
#
# Everything::Cron::Runner -- the DETACHED dispatch path (heavy daily jobs like
# generate-sitemap). Verifies the leader hands the job to a background supervisor and
# returns WITHOUT blocking the tick (never enters _wait_with_timeout), marks the job
# 'running' so the next tick won't relaunch it, and respects dry-run. The real fork/
# exec is stubbed (_spawn_supervisor overridden) so the test is deterministic and
# touches neither a real process nor the DB.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;
use Everything::Cron::Schedule;

initEverything 'everything';

# --- a fake State that records mark_started/mark_finished instead of writing the DB.
{
    package FakeState;
    use Moose;
    extends 'Everything::Cron::State';
    has 'started'  => ( is => 'ro', default => sub { [] } );
    has 'finished' => ( is => 'ro', default => sub { [] } );
    sub mark_started  { my ( $s, $job, $pid ) = @_; push @{ $s->started },  [ $job, $pid ]; return 1; }
    sub mark_finished { my ( $s, $job, $st )  = @_; push @{ $s->finished }, [ $job, $st ];  return 1; }
    __PACKAGE__->meta->make_immutable;
}

# --- a Runner whose supervisor spawn is stubbed (records the call, no fork), and whose
#     blocking wait DIES -- so if a detached job ever reaches the blocking path the
#     test fails loudly.
{
    package StubRunner;
    use Moose;
    extends 'Everything::Cron::Runner';
    has 'spawned'   => ( is => 'ro', default => sub { [] } );
    has 'spawn_pid' => ( is => 'rw', default => 7777 );
    sub _spawn_supervisor {
        my ( $self, $entry ) = @_;
        push @{ $self->spawned }, $entry->{name};
        return $self->spawn_pid;    # 0/undef simulates fork failure
    }
    sub _wait_with_timeout { die "detached job must NOT reach the blocking wait path\n" }
    __PACKAGE__->meta->make_immutable;
}

my $sched = Everything::Cron::Schedule->new;
my $entry = $sched->entry('generate-sitemap');
ok( $entry && $entry->{detached}, 'generate-sitemap is a detached entry' );

# --- happy path: spawn supervisor + mark running, never block ------------------
{
    my $state = FakeState->new;
    my $r = StubRunner->new( state => $state, schedule => $sched, spawn_pid => 4242 );
    $r->run_job($entry);

    is_deeply( $r->spawned, ['generate-sitemap'], 'leader spawned the supervisor exactly once' );
    is_deeply( $state->started, [ [ 'generate-sitemap', 4242 ] ],
        "job marked 'running' with the supervisor pid (next tick will skip it)" );
    is( scalar @{ $state->finished }, 0, 'leader does NOT mark finished -- the supervisor owns that' );
}

# --- fork failure: no supervisor pid -> leave the row untouched (retry next tick) --
{
    my $state = FakeState->new;
    my $r = StubRunner->new( state => $state, schedule => $sched, spawn_pid => 0 );
    $r->run_job($entry);

    is_deeply( $r->spawned, ['generate-sitemap'], 'spawn was attempted' );
    is( scalar @{ $state->started }, 0, 'on fork failure the job is NOT marked running (so it retries)' );
}

# --- dry-run: log only, never spawn -------------------------------------------
{
    my $state = FakeState->new;
    my $r = StubRunner->new( state => $state, schedule => $sched, dry_run => 1 );
    $r->run_job($entry);

    is( scalar @{ $r->spawned },      0, 'dry-run does not spawn a supervisor' );
    is( scalar @{ $state->started },  0, 'dry-run does not mark the job running' );
}

done_testing();
