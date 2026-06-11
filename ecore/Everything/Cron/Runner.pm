package Everything::Cron::Runner;

use Moose;
use namespace::autoclean;
use DBI ();
use POSIX qw(:sys_wait_h);
use Time::HiRes ();

with 'Everything::Globals';

use Everything::Cron::Schedule;
use Everything::Cron::State;
use Everything::Cron::Health;

# Everything::Cron::Runner -- the in-webhead cron engine (docs/cron-sidecar.md).
#
# PERIODIC model: a thin trigger (a supervised `run_once; sleep 60` loop, or OS
# crond) invokes run_once on each webhead every ~minute. run_once grabs a MySQL
# GET_LOCK (non-blocking), and whoever wins runs the due jobs once, then releases.
# The lock is held ONLY for the duration of a run -- between runs nothing is held,
# so there is no persistent leader to wedge, no idle lock connection to keep alive,
# and failover is automatic (the next trigger re-contends on a free lock). A random
# pre-lock jitter spreads the webheads and rotates who does the work.

has 'lock_wait_timeout' => ( isa => 'Int', is => 'ro', default => 120 );
has 'kill_grace'        => ( isa => 'Int', is => 'ro', default => 5 );
has 'maintain_every'    => ( isa => 'Int', is => 'ro', default => 30 );  # keep lock alive during long jobs
has 'jitter_max'        => ( isa => 'Int', is => 'ro', default => 0 );   # prod multi-webhead spread
has 'dry_run'           => ( isa => 'Bool', is => 'rw', default => 0 );

has 'schedule' => ( isa => 'Everything::Cron::Schedule', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::Schedule->new } );
has 'state'    => ( isa => 'Everything::Cron::State', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::State->new } );
has 'lock_name' => ( isa => 'Str', is => 'ro', lazy => 1,
    default => sub { Everything::Cron::State::LEADER_LOCK() } );

has '_lock_dbh' => ( is => 'rw', predicate => '_has_lock_dbh', clearer => '_clear_lock_dbh' );
has '_stop'     => ( is => 'rw', default => 0 );

#############################################################################
# One run: contend for the lock, run what's due, release.
#############################################################################

sub run_once {
    my ($self) = @_;
    $self->_install_signal_handlers;
    $self->_jitter;

    my $dbh = $self->_connect_lock or return;
    my ($got) = eval { $dbh->selectrow_array( 'SELECT GET_LOCK(?, 0)', undef, $self->lock_name ) };
    unless ($got) {
        eval { $dbh->disconnect; 1 } or $self->_log( 'lock-conn disconnect failed: ' . ( $@ || 'unknown' ) );
        return;    # another webhead is running this minute -- nothing to do
    }
    $self->_lock_dbh($dbh);
    $self->_log( 'leader for this run' . ( $self->dry_run ? ' (DRY RUN)' : '' ) );

    eval {
        $self->state->heartbeat_leader;
        $self->_run_due_jobs;
        $self->_emit_health_metric;
        1;
    } or $self->_log("run error: $@");

    eval { $dbh->do( 'SELECT RELEASE_LOCK(?)', undef, $self->lock_name ); 1 }
        or $self->_log( 'release_lock failed: ' . ( $@ || 'unknown' ) );
    eval { $dbh->disconnect; 1 }
        or $self->_log( 'lock-conn disconnect failed: ' . ( $@ || 'unknown' ) );
    $self->_clear_lock_dbh;
    return;
}

sub _run_due_jobs {
    my ($self) = @_;
    my $now  = time;
    my $jobs = $self->state->snapshot->{jobs};
    for my $entry ( @{ $self->schedule->entries } ) {
        last if $self->_stop;
        my $name = $entry->{name};
        my $js   = $jobs->{$name};

        # Init-on-first-sight: a job with no cron_state row yet (fresh deploy / dev
        # rebuild) is seeded to "now" WITHOUT running, so a cold cron_state doesn't
        # fire every job at once. It then fires at its normal next interval.
        unless ($js) {
            $self->state->mark_seen($name);
            next;
        }
        next if $self->_in_progress( $entry, $js );
        next unless $self->schedule->due( $entry, $now, $js->{started_at} || 0 );
        $self->run_job($entry);
    }
    return;
}

# A row left 'running' by a crashed prior run: in-progress until its timeout
# elapses, then presumed dead (Health flags 'hung') and a fresh run is allowed.
sub _in_progress {
    my ( $self, $entry, $js ) = @_;
    return 0 unless ( $js->{status} || '' ) eq 'running';
    return ( time - ( $js->{started_at} || 0 ) ) < $entry->{timeout} ? 1 : 0;
}

#############################################################################
# Dedicated lock connection (NOT connect_cached -- the lock lives on it)
#############################################################################

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
                mysql_auto_reconnect => 0,    # a reconnect = new session = lock lost
            } );
    };
    if ( !$dbh ) {
        $self->_log( 'lock connection failed: ' . ( $@ || $DBI::errstr || 'unknown' ) );
        return;
    }
    # Bound the ghost-lock window if this process is hard-killed mid-run: the
    # server reaps the idle session (releasing the lock) after wait_timeout. We
    # ping during long jobs (below) so it never reaps while we're actively working.
    eval { $dbh->do( 'SET SESSION wait_timeout = ' . $self->lock_wait_timeout ); 1 }
        or $self->_log( 'could not set lock wait_timeout: ' . ( $@ || 'unknown' ) );
    return $dbh;
}

#############################################################################
# Job execution (fork + exec, timeout-kill, lock kept alive during long jobs)
#############################################################################

sub run_job {
    my ( $self, $entry ) = @_;
    my $name = $entry->{name};

    if ( $self->dry_run ) {
        $self->_log( '[dry-run] would run ' . $name . ( $entry->{detached} ? ' (detached)' : '' ) );
        return;
    }

    return $self->_run_detached($entry) if $entry->{detached};

    my $start = Time::HiRes::time();
    my $pid   = fork;
    if ( !defined $pid ) {
        $self->_log("fork failed for $name: $!");
        return;
    }
    if ( $pid == 0 ) {
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

# Detached execution (heavy daily batch jobs -- e.g. generate-sitemap). The leader
# hands the job to a BACKGROUND supervisor (cron/cron_supervise.pl) and returns at
# once, so it neither blocks the ~1min tick nor pins the GET_LOCK for the job's whole
# runtime (a 50min blocking run starved datastash and held the lock the entire time).
# We mark the job 'running' here, under the lock, BEFORE returning -- so the next
# tick's _in_progress check skips it (no double-launch) and Health reads it as a
# healthy in-progress run until its (generous) timeout. The supervisor owns the
# fork/exec, the timeout-kill, and the mark_finished, on its own DB connection.
sub _run_detached {
    my ( $self, $entry ) = @_;
    my $name = $entry->{name};

    my $pid = $self->_spawn_supervisor($entry);
    return unless $pid;    # fork failed -- logged; leave the row untouched so it retries

    # Record 'running' (supervisor pid) on the leader's own connection. A non-trivial
    # detached job cannot finish before this line, so there is no mark_finished race.
    $self->state->mark_started( $name, $pid );
    $self->_log("started $name (detached, supervisor pid $pid)");
    return;
}

# Fork a fully-detached supervisor and exec cron/cron_supervise.pl into it. setsid
# so it survives the leader's exit (it is reparented to init) and isn't taken out by
# a signal to the runner's process group. We exec immediately -- the child shares no
# live Perl state with the leader, and the inherited lock/DB sockets are never touched
# (the supervisor opens its own via initEverything). Returns the supervisor pid, or
# undef on fork failure.
sub _spawn_supervisor {
    my ( $self, $entry ) = @_;
    my @argv = $self->_supervise_argv($entry);
    my $pid  = fork;
    if ( !defined $pid ) {
        $self->_log( "fork failed (supervisor) for $entry->{name}: $!" );
        return;
    }
    if ( $pid == 0 ) {
        POSIX::setsid();
        exec { $argv[0] } @argv;
        print STDERR "[cron] exec failed (supervise) for $entry->{name}: $!\n";
        POSIX::_exit(127);
    }
    return $pid;
}

# Build the argv that runs cron_supervise.pl <name> <timeout> -- <the job's own argv>.
# (Same perl invocation prefix the schedule uses for the job scripts themselves.)
sub _supervise_argv {
    my ( $self, $entry ) = @_;
    return (
        '/usr/bin/perl', '-Mlib=/var/everything/ecore', '-Mlib=/var/libraries/lib/perl5',
        '/var/everything/cron/cron_supervise.pl',
        $entry->{name}, $entry->{timeout}, '--',
        @{ $entry->{argv} },
    );
}

# Wait for $pid up to $timeout, keeping the lock connection alive (a long job --
# e.g. datastash-lengthy -- holds the lock for its whole run, so the dedicated
# connection must be pinged or wait_timeout would reap it and free the lock under
# us). On timeout or SIGTERM, kill TERM->KILL and reap. Returns ($exit, $timed_out).
sub _wait_with_timeout {
    my ( $self, $pid, $timeout ) = @_;
    my $deadline   = time + $timeout;
    my $last_maint = time;

    while (1) {
        my $reaped = waitpid( $pid, WNOHANG );
        return ( $? >> 8, 0 ) if $reaped == $pid;
        return ( 0, 0 ) if $reaped == -1;

        if ( $self->_stop ) {
            $self->_log("SIGTERM -- terminating job pid $pid");
            $self->_kill_child($pid);
            return ( -1, 0 );
        }
        if ( time >= $deadline ) {
            $self->_log("TIMEOUT -- job pid $pid exceeded ${timeout}s");
            $self->_kill_child($pid);
            return ( -1, 1 );
        }
        if ( time - $last_maint >= $self->maintain_every ) {
            eval { $self->_lock_dbh->ping if $self->_has_lock_dbh; 1 }
                or $self->_log('lock ping failed during job');
            eval { $self->state->heartbeat_leader; 1 }
                or $self->_log('heartbeat failed during job');
            $self->_emit_health_metric;    # keep the metric flowing during a long job
            $last_maint = time;
        }
        sleep 1;
    }
    return;    # unreachable (loop only exits via return)
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
# Misc
#############################################################################

sub _jitter {
    my ($self) = @_;
    return if $self->jitter_max <= 0;
    my $s = int( rand( $self->jitter_max ) );    ## no critic (ProhibitMagicNumbers)
    sleep $s if $s > 0;
    return;
}

sub _install_signal_handlers {
    my ($self) = @_;
    ## no critic (RequireLocalizedPunctuationVars) -- must persist for the run
    $SIG{TERM} = sub { $self->_stop(1) };
    $SIG{INT}  = sub { $self->_stop(1) };
    ## use critic
    return;
}

# Publish the cron health metric (E2/Cron UnhealthyJobs = wedged + failing count)
# to CloudWatch. The leader emits it each run and during long jobs; the CFN alarm
# (TreatMissingData=breaching) fires on >0 OR on missing data -- i.e. wedged/failing
# jobs OR total cron death (no leader emitting). Skipped in dry-run shadow (jobs
# aren't running, so they would read as falsely overdue) and in dev (no CloudWatch).
sub _emit_health_metric {
    my ($self) = @_;
    return if $self->dry_run;
    # Metric emission must never break a run -- wrap the snapshot/evaluate too.
    eval {
        my $verdict = Everything::Cron::Health->new( schedule => $self->schedule )
            ->evaluate( $self->state->snapshot, time );
        $self->_emit_metric( scalar( @{ $verdict->{wedged} } ) + scalar( @{ $verdict->{failing} } ) );
        1;
    } or $self->_log( 'health metric failed: ' . ( $@ || 'unknown' ) );
    return;
}

sub _emit_metric {
    my ( $self, $value ) = @_;
    return if $self->CONF->environment eq 'development';
    eval {
        require Paws;
        my $cw = Paws->service( 'CloudWatch', region => $self->CONF->current_region );
        $cw->PutMetricData(
            Namespace  => 'E2/Cron',
            MetricData => [ { MetricName => 'UnhealthyJobs', Value => $value + 0, Unit => 'Count' } ],
        );
        1;
    } or $self->_log( 'CloudWatch metric emit failed: ' . ( $@ || 'unknown' ) );
    return;
}

sub _log {
    my ( $self, $msg ) = @_;
    print STDERR '[cron] ' . localtime() . " $msg\n";
    return;
}

__PACKAGE__->meta->make_immutable;
1;
