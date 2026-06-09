package Everything::Cron::State;

use Moose;
use namespace::autoclean;
use Sys::Hostname ();

with 'Everything::Globals';

# Everything::Cron::State
#
# The persistence layer for the in-webhead cron runner: it reads/writes the two
# peripheral tables (cron_state, one row per job; cron_leader, one heartbeat row)
# and produces the epoch-keyed snapshot that Everything::Cron::Health consumes.
#
# It deliberately knows nothing about scheduling, leader election, or the GET_LOCK
# (those live in the Runner). It is pure table I/O over the normal $DB handle, so
# it is cheap to call every tick. All times are stored as DATETIME (E2 convention,
# cf. collaboration.locktime) and read back as epoch seconds via UNIX_TIMESTAMP so
# Health keeps working in epochs without conversion. Writes use sqlInsert's native
# ON DUPLICATE KEY UPDATE for atomic, injection-safe upserts.

# Constants as subs (not the 'constant' pragma -- that pragma is themed 'bugs'
# in Perl::Critic for its hash-key interpolation footgun).
sub LEADER_LOCK     { return 'e2cron_leader' }
sub OUTPUT_TAIL_MAX { return 2000 }    # bound last_output_tail to the column width

# Which task/container this process is — for observability and the "current
# leader" field. ECS/Docker set HOSTNAME to the container id; fall back to uname.
has 'host' => ( isa => 'Str', is => 'ro', lazy => 1, builder => '_build_host' );

sub _build_host {
    return $ENV{HOSTNAME} || Sys::Hostname::hostname() || 'unknown';
}

# ---------------------------------------------------------------------------
# Leader heartbeat (cron_leader)
# ---------------------------------------------------------------------------

# Called every tick by whoever currently holds the GET_LOCK. Bumps the single
# cron_leader row so Health can see the leader is alive (now - heartbeat).
sub heartbeat_leader {
    my ($self) = @_;
    return $self->DB->sqlInsert(
        'cron_leader',
        { lock_name => LEADER_LOCK, host => $self->host, '-heartbeat' => 'NOW()' },
        { host      => $self->host,                      '-heartbeat' => 'NOW()' },
    );
}

# ---------------------------------------------------------------------------
# Per-job run state (cron_state)
# ---------------------------------------------------------------------------

# Mark a job as started: status=running, fresh started_at, child pid. Leaves
# last_success / consecutive_failures untouched (those reflect the prior run).
sub mark_started {
    my ( $self, $job, $pid ) = @_;
    my %fields = (
        status       => 'running',
        '-started_at' => 'NOW()',
        '-finished_at' => 'NULL',
        pid          => $pid,
        host         => $self->host,
        '-heartbeat' => 'NOW()',
    );
    return $self->DB->sqlInsert( 'cron_state', { job => $job, %fields }, { %fields } );
}

# Mark a job finished. $status is 'ok' | 'fail' | 'timeout'. On success we stamp
# last_success and zero the failure streak; on failure we increment it (so Health
# can flag 'failing' after N in a row).
sub mark_finished {
    my ( $self, $job, $status, %args ) = @_;
    my $ok   = ( $status eq 'ok' ) ? 1 : 0;
    my $tail = defined $args{output_tail} ? substr( $args{output_tail}, 0, OUTPUT_TAIL_MAX ) : undef;

    # Fields written the same way on both the INSERT and the UPDATE branch.
    my %common = (
        status           => $status,
        '-finished_at'   => 'NOW()',
        duration_ms      => $args{duration_ms},
        last_output_tail => $tail,
        host             => $self->host,
        pid              => undef,             # no longer running
        '-heartbeat'     => 'NOW()',
    );

    # Failure-streak + last_success differ between first-insert and update.
    my %insert = (
        %common,
        ( $ok ? ( '-last_success' => 'NOW()', consecutive_failures => 0 )
              : ( consecutive_failures => 1 ) ),
    );
    my %update = (
        %common,
        ( $ok ? ( '-last_success' => 'NOW()', '-consecutive_failures' => '0' )
              : ( '-consecutive_failures' => 'consecutive_failures + 1' ) ),
    );

    return $self->DB->sqlInsert( 'cron_state', { job => $job, %insert }, { %update } );
}

# Baseline a never-run job at "now" (both started_at and last_success) so a cold
# cron_state -- a fresh deploy or a dev rebuild -- does NOT make every job look
# immediately due (a stampede) or overdue to Health before it has had a chance to
# run. It then fires at its normal next interval; if it later fails to run, the
# last_success seeded here ages out and Health flags it for real.
sub mark_seen {
    my ( $self, $job ) = @_;
    my %fields = (
        status          => 'idle',
        '-started_at'    => 'NOW()',
        '-last_success'  => 'NOW()',
        host            => $self->host,
        '-heartbeat'    => 'NOW()',
    );
    return $self->DB->sqlInsert( 'cron_state', { job => $job, %fields }, { %fields } );
}

# ---------------------------------------------------------------------------
# Snapshot for Health
# ---------------------------------------------------------------------------

# Read both tables and return the structure Everything::Cron::Health->evaluate
# expects, with all DATETIMEs rendered as epoch seconds (NULL -> undef = "never").
sub snapshot {
    my ($self) = @_;

    my $leader = $self->DB->sqlSelectHashref(
        'host, UNIX_TIMESTAMP(heartbeat) AS heartbeat',
        'cron_leader',
        "lock_name = '" . LEADER_LOCK . "'",
    ) || {};

    my %jobs;
    my $csr = $self->DB->sqlSelectMany(
        'job, status, host, pid, duration_ms, consecutive_failures, last_output_tail, '
            . 'UNIX_TIMESTAMP(started_at) AS started_at, '
            . 'UNIX_TIMESTAMP(finished_at) AS finished_at, '
            . 'UNIX_TIMESTAMP(last_success) AS last_success, '
            . 'UNIX_TIMESTAMP(heartbeat) AS heartbeat',
        'cron_state',
    );
    if ($csr) {
        while ( my $r = $csr->fetchrow_hashref ) {
            $jobs{ delete $r->{job} } = $r;
        }
        $csr->finish;
    }

    return {
        leader => { heartbeat => $leader->{heartbeat}, host => $leader->{host} },
        jobs   => \%jobs,
    };
}

__PACKAGE__->meta->make_immutable;
1;
