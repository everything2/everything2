package Everything::Cron::Health;

use Moose;
use namespace::autoclean;

# Everything::Cron::Health
#
# The wedge evaluator. Given a point-in-time snapshot of cron run state plus the
# schedule, decide whether the cron subsystem is healthy or wedged -- WITHOUT
# touching the DB or the clock itself (both are passed in), so it is pure and
# fully unit-testable, and can be called from anywhere: the runner (to emit a
# CloudWatch metric), the /health endpoint (?cron), or a CLI inspector.
#
# It is the PASSIVE counterpart to the schedule's per-job timeout (the ACTIVE
# anti-wedge mechanism the runner enforces by killing an over-running child).
# This catches the failures the in-process timeout cannot: the leader process
# itself dying/hanging, a job that never got scheduled because a sibling starved
# it, or a job failing every run.
#
# Wedge taxonomy (per job):
#   ok        -- ran recently and succeeded (or is legitimately mid-run)
#   running   -- currently executing, within its timeout (healthy in-progress)
#   hung      -- status=running but started_at is older than the job's timeout
#                -> the runner should have killed it; if we still see this, the
#                   runner itself is likely wedged. The loudest signal.
#   overdue   -- no successful completion within period * overdue_factor; it was
#                supposed to run and didn't (starved, or the leader is down)
#   failing   -- consecutive_failures >= fail_threshold
#
# And for the subsystem:
#   leader stale -- the leader heartbeat is older than leader_stale_secs; no job
#                   can make progress (failover hasn't completed, or all webheads
#                   are down). Dominates: if the leader is stale the whole thing
#                   is 'down' regardless of per-job state.
#
# overall: down  (leader stale)  >  degraded (any hung/overdue/failing)  >  ok

has 'leader_stale_secs' => ( isa => 'Int', is => 'ro', default => 90 );
has 'overdue_factor'    => ( isa => 'Num', is => 'ro', default => 2 );
has 'fail_threshold'    => ( isa => 'Int', is => 'ro', default => 3 );
has 'schedule'          => ( isa => 'Everything::Cron::Schedule', is => 'ro', required => 1 );

# evaluate($state, $now) -> verdict hashref
#
# $state = {
#   leader => { heartbeat => epoch, host => str },         # may be absent
#   jobs   => { <name> => {
#       status               => 'ok'|'running'|'fail'|'timeout',
#       started_at           => epoch,   # last run start
#       finished_at          => epoch,   # last run end (absent while running)
#       last_success         => epoch,   # last ok completion
#       duration_ms          => int,
#       consecutive_failures => int,
#       pid                  => int,
#       host                 => str,
#   }, ... }
# }
sub evaluate {
    my ( $self, $state, $now ) = @_;
    $state ||= {};
    my $jobs_state = $state->{jobs} || {};

    # --- leader liveness ---
    my $hb        = ( $state->{leader} || {} )->{heartbeat} || 0;
    my $hb_age    = $hb ? $now - $hb : undef;
    my $hb_stale  = !$hb || $hb_age > $self->leader_stale_secs ? 1 : 0;
    my $leader = {
        state     => $hb_stale ? 'stale' : 'ok',
        heartbeat => $hb || undef,
        age       => $hb_age,
        host      => ( $state->{leader} || {} )->{host},
    };

    # --- per-job verdicts ---
    my %jobs;
    my ( @wedged, @failing );
    foreach my $entry ( @{ $self->schedule->entries } ) {
        my $name = $entry->{name};
        my $s    = $jobs_state->{$name} || {};
        my $period = $self->schedule->expected_period($entry);
        my $verdict = $self->_job_verdict( $entry, $s, $now, $period );
        $jobs{$name} = $verdict;
        push @wedged,  $name if $verdict->{state} eq 'hung' || $verdict->{state} eq 'overdue';
        push @failing, $name if $verdict->{state} eq 'failing';
    }

    # --- subsystem rollup ---
    my $overall =
        $hb_stale                  ? 'down'
      : ( @wedged || @failing )    ? 'degraded'
      :                              'ok';

    return {
        overall => $overall,
        leader  => $leader,
        jobs    => \%jobs,
        wedged  => [ sort @wedged ],     # hung or overdue -- the actionable "stuck" set
        failing => [ sort @failing ],
        summary => $self->_summary( $overall, $leader, \@wedged, \@failing ),
    };
}

sub _job_verdict {
    my ( $self, $entry, $s, $now, $period ) = @_;
    my $status = $s->{status} || 'unknown';

    # Currently executing: healthy until it blows its timeout, then HUNG.
    if ( $status eq 'running' ) {
        my $run_age = $now - ( $s->{started_at} || $now );
        if ( $run_age > $entry->{timeout} ) {
            return {
                state    => 'hung',
                run_age  => $run_age,
                timeout  => $entry->{timeout},
                pid      => $s->{pid},
                host     => $s->{host},
            };
        }
        return { state => 'running', run_age => $run_age, pid => $s->{pid}, host => $s->{host} };
    }

    # Not running: failing dominates, then overdue, else ok.
    my $fails = $s->{consecutive_failures} || 0;
    if ( $fails >= $self->fail_threshold ) {
        return { state => 'failing', consecutive_failures => $fails, last_status => $status };
    }

    my $last_ok = $s->{last_success} || 0;
    my $age     = $last_ok ? $now - $last_ok : undef;
    # Never-succeeded jobs only count as overdue once they've existed long enough
    # to have been expected to run (period * factor since we started watching is
    # not knowable here, so a never-run job is reported 'overdue' so it surfaces).
    if ( !$last_ok || $age > $period * $self->overdue_factor ) {
        return {
            state        => 'overdue',
            last_success => $last_ok || undef,
            age          => $age,
            period       => $period,
        };
    }

    return { state => 'ok', last_success => $last_ok, age => $age };
}

sub _summary {
    my ( $self, $overall, $leader, $wedged, $failing ) = @_;
    return "cron leader stale (heartbeat age ${\ ($leader->{age} // 'n/a')}s) -- subsystem DOWN"
        if $overall eq 'down';
    return 'cron ok' if $overall eq 'ok';
    my @parts;
    push @parts, 'wedged: ' . join( ',', @$wedged )   if @$wedged;
    push @parts, 'failing: ' . join( ',', @$failing ) if @$failing;
    return 'cron degraded -- ' . join( '; ', @parts );
}

__PACKAGE__->meta->make_immutable;
1;
