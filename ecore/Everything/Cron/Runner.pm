package Everything::Cron::Runner;

use Moose;
use namespace::autoclean;
use DBI ();
use POSIX qw(:sys_wait_h);
use Time::HiRes ();

with 'Everything::Globals';

use Everything::Cron::Schedule;
use Everything::Cron::State;

# Everything::Cron::Runner
#
# The in-webhead cron engine (docs/cron-sidecar-design.md). One of these runs in
# every webhead task; exactly one is the *leader* at a time, enforced by a MySQL
# GET_LOCK held on a DEDICATED connection. The leader ticks the schedule and runs
# each due job sequentially (fork+exec of the existing cron_*.pl), with a per-job
# timeout-kill so one hung job can't starve the rest. Non-leaders idle and retry
# the lock; if the leader dies its connection drops and the lock auto-releases, so
# another runner takes over. State + heartbeat live in cron_state/cron_leader
# (Everything::Cron::State); health is judged by Everything::Cron::Health.

has 'tick_seconds' => ( isa => 'Int',  is => 'ro', default => 15 );
has 'lock_wait_timeout' => ( isa => 'Int', is => 'ro', default => 120 );
has 'kill_grace' => ( isa => 'Int', is => 'ro', default => 5 );
has 'dry_run'  => ( isa => 'Bool', is => 'rw', default => 0 );    # shadow mode: log, don't run

has 'schedule' => ( isa => 'Everything::Cron::Schedule', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::Schedule->new } );
has 'state'    => ( isa => 'Everything::Cron::State', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::State->new } );

has 'lock_name' => ( isa => 'Str', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::State::LEADER_LOCK() } );

has '_lock_dbh'  => ( is => 'rw', predicate => '_has_lock_dbh', clearer => '_clear_lock_dbh' );
has '_is_leader' => ( is => 'rw', default => 0 );
has '_stop'      => ( is => 'rw', default => 0 );

#############################################################################
# Main loop
#############################################################################

sub run {
    my ($self) = @_;
    $self->_install_signal_handlers;
    $self->_log( 'starting on ' . $self->state->host . ( $self->dry_run ? ' (DRY RUN)' : '' ) );

    until ( $self->_stop ) {
        eval { $self->tick; 1 } or $self->_log("tick error: $@");
        # Sleep the tick interval in 1s steps so SIGTERM is honored promptly.
        my $slept = 0;
        while ( $slept < $self->tick_seconds && !$self->_stop ) { sleep 1; $slept++; }
    }
    $self->_shutdown;
    return;
}

sub tick {
    my ($self) = @_;
    $self->_ensure_leadership;
    return unless $self->_is_leader;

    $self->state->heartbeat_leader;

    my $jobs = $self->state->snapshot->{jobs};
    for my $entry ( @{ $self->schedule->entries } ) {
        last if $self->_stop;
        next if !$self->_is_leader;                 # may be lost mid-tick during a long job
        my $js = $jobs->{ $entry->{name} } || {};
        next if $self->_in_progress( $entry, $js );
        next unless $self->schedule->due( $entry, time, $js->{started_at} || 0 );
        $self->run_job($entry);
    }
    return;
}

# A row left 'running' by a crashed prior leader: still in-progress until its
# timeout elapses; past that it's presumed dead (Health flags it 'hung') and we
# allow a fresh run.
sub _in_progress {
    my ( $self, $entry, $js ) = @_;
    return 0 unless ( $js->{status} || '' ) eq 'running';
    return ( time - ( $js->{started_at} || 0 ) ) < $entry->{timeout} ? 1 : 0;
}

#############################################################################
# Leadership (GET_LOCK on a dedicated connection)
#############################################################################

sub _ensure_leadership {
    my ($self) = @_;

    if ( !$self->_has_lock_dbh || !$self->_lock_dbh->ping ) {
        $self->_is_leader(0);
        $self->_clear_lock_dbh if $self->_has_lock_dbh;
        return unless $self->_connect_lock;
    }
    return if $self->_is_leader;

    my ($got) = eval {
        $self->_lock_dbh->selectrow_array( 'SELECT GET_LOCK(?, 0)', undef, $self->lock_name );
    };
    if ($got) {
        $self->_is_leader(1);
        $self->_log('acquired cron leadership');
    }
    return;
}

# Keep leadership alive DURING a long-running job: a synchronous job blocks the
# tick, so without this the heartbeat would go stale and -- worse -- the lock
# connection would idle past wait_timeout and the lock would be reaped, letting a
# second leader start. Called periodically from the job wait loop.
sub _maintain_leadership {
    my ($self) = @_;
    if ( $self->_has_lock_dbh && $self->_lock_dbh->ping ) {
        $self->state->heartbeat_leader;
    }
    else {
        $self->_log('lock connection dropped during a job -- lost leadership');
        $self->_is_leader(0);
        $self->_clear_lock_dbh if $self->_has_lock_dbh;
    }
    return;
}

sub _connect_lock {
    my ($self) = @_;
    my $conf = $self->CONF;
    my $dsn  = 'DBI:mysql:database=' . $conf->database
        . ';host=' . $conf->everything_dbserv
        . ';port=' . $conf->everything_dbport
        . ';mysql_ssl=1;mysql_get_server_pubkey=1';
    my $dbh = eval {
        DBI->connect( $dsn, $conf->everyuser, $conf->everypass,
            {
                AutoCommit           => 1,
                RaiseError           => 0,
                PrintError           => 0,
                mysql_auto_reconnect => 0,    # MUST be off: a reconnect = new session = lock lost
            } );
    };
    if ( !$dbh ) {
        $self->_log( 'lock connection failed: ' . ( $@ || $DBI::errstr || 'unknown' ) );
        return 0;
    }
    # Bound the post-SIGKILL ghost-lock window: if this container is hard-killed,
    # the server reaps this idle session (releasing the lock) after wait_timeout.
    # We ping every tick (<< this), so it never reaps while we're alive.
    eval { $dbh->do( 'SET SESSION wait_timeout = ' . $self->lock_wait_timeout ); 1 }
        or $self->_log( 'could not set lock-connection wait_timeout: ' . ( $@ || 'unknown' ) );
    $self->_lock_dbh($dbh);
    return 1;
}

#############################################################################
# Job execution (fork + exec, timeout-kill)
#############################################################################

sub run_job {
    my ( $self, $entry ) = @_;
    my $name = $entry->{name};

    if ( $self->dry_run ) {
        $self->_log("[dry-run] would run $name");
        return;
    }

    my $start = Time::HiRes::time();
    my $pid   = fork;
    if ( !defined $pid ) {
        $self->_log("fork failed for $name: $!");
        return;
    }
    if ( $pid == 0 ) {
        # Child: become the job. Output flows to the runner's stdout/stderr ->
        # CloudWatch. exec replaces the process; only reached on exec failure.
        exec { $entry->{argv}[0] } @{ $entry->{argv} };
        print STDERR "[cron] exec failed for $name: $!\n";
        POSIX::_exit(127);
    }

    $self->state->mark_started( $name, $pid );
    $self->_log("started $name (pid $pid)");

    my ( $exit, $timed_out ) = $self->_wait_with_timeout( $pid, $entry->{timeout} );
    my $dur_ms = int( ( Time::HiRes::time() - $start ) * 1000 );
    my $result = $timed_out ? 'timeout' : ( $exit == 0 ? 'ok' : 'fail' );

    $self->state->mark_finished( $name, $result, duration_ms => $dur_ms );
    $self->_log( "$name finished: $result (${dur_ms}ms)"
            . ( $timed_out ? ' [TIMEOUT -> killed]' : ( $result eq 'fail' ? " [exit $exit]" : '' ) ) );
    return;
}

# Wait for $pid up to $timeout seconds, maintaining leadership meanwhile. On
# timeout (or runner SIGTERM) kill the child TERM->KILL and reap it.
# Returns ($exit_code, $timed_out).
sub _wait_with_timeout {
    my ( $self, $pid, $timeout ) = @_;
    my $deadline   = time + $timeout;
    my $last_maint = time;

    while (1) {
        my $reaped = waitpid( $pid, WNOHANG );
        return ( $? >> 8, 0 ) if $reaped == $pid;
        return ( 0, 0 ) if $reaped == -1;            # already gone

        if ( $self->_stop ) {
            $self->_log("SIGTERM received -- terminating job pid $pid");
            $self->_kill_child($pid);
            return ( -1, 0 );
        }
        if ( time >= $deadline ) {
            $self->_log("TIMEOUT -- job pid $pid exceeded ${timeout}s");
            $self->_kill_child($pid);
            return ( -1, 1 );
        }
        if ( time - $last_maint >= $self->tick_seconds ) {
            $self->_maintain_leadership;
            $last_maint = time;
        }
        sleep 1;
    }
    return;    # unreachable (the loop only exits via return) -- satisfies RequireFinalReturn
}

sub _kill_child {
    my ( $self, $pid ) = @_;
    kill 'TERM', $pid;
    my $grace = time + $self->kill_grace;
    while ( time < $grace ) {
        return if waitpid( $pid, WNOHANG ) == $pid;
        sleep 1;
    }
    kill 'KILL', $pid if kill( 0, $pid );
    waitpid( $pid, 0 );
    return;
}

#############################################################################
# Lifecycle
#############################################################################

sub _install_signal_handlers {
    my ($self) = @_;
    # Daemon handlers must persist process-wide for the runner's whole life, so
    # they are deliberately NOT localized (the usual punctuation-var guidance).
    ## no critic (RequireLocalizedPunctuationVars)
    $SIG{TERM} = sub { $self->_stop(1) };
    $SIG{INT}  = sub { $self->_stop(1) };
    ## use critic
    return;
}

sub _shutdown {
    my ($self) = @_;
    $self->_log('shutting down');
    if ( $self->_is_leader && $self->_has_lock_dbh ) {
        eval { $self->_lock_dbh->do( 'SELECT RELEASE_LOCK(?)', undef, $self->lock_name ); 1 }
            or $self->_log( 'release_lock on shutdown failed: ' . ( $@ || 'unknown' ) );
        eval { $self->_lock_dbh->disconnect; 1 }
            or $self->_log( 'lock disconnect on shutdown failed: ' . ( $@ || 'unknown' ) );
        $self->_log('released cron leadership');
    }
    return;
}

sub _log {
    my ( $self, $msg ) = @_;
    print STDERR '[cron] ' . localtime() . " $msg\n";
    return;
}

__PACKAGE__->meta->make_immutable;
1;
