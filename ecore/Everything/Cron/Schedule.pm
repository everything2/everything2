package Everything::Cron::Schedule;

use Moose;
use namespace::autoclean;

# Everything::Cron::Schedule
#
# The declarative cron schedule for the in-webhead cron runner (see
# docs/cron-sidecar-design.md). This mirrors the 8 EventBridge rules that
# currently RunTask the e2cron-family Fargate task, one entry per job. The
# schedule lives in CODE; per-job run STATE lives in the DB (Everything::Cron::State).
#
# Each entry carries, besides its cadence:
#   timeout  -- the wall-clock ceiling for a single run. This is the ACTIVE
#               anti-wedge mechanism: the runner SIGTERM/SIGKILLs a child that
#               exceeds it, so one hung job can't starve the sequential runner.
#               Set generously above observed runtime, but bounded.
#   local    -- 1 = run in-place on the leader webhead (light jobs); 0 = the
#               leader should dispatch it to e2heavyjob-family instead (reserved
#               for datastash --lengthy if it ever pressures request latency).
#
# Cadence is expressed two ways, faithful to the current EventBridge rules:
#   type 'rate' + interval (s)  -- fire when interval has elapsed since last run
#                                  (the rate(N) rules, incl. the daily ones).
#   type 'cron' + cron (5-field) -- fire on a wall-clock schedule (the cron(...)
#                                  rules). 'period' is the nominal gap, used only
#                                  by the health evaluator's overdue math.

# Argv prefix every job script shares (matches the EventBridge command override).
my @PERL = ( '/usr/bin/perl', '-Mlib=/var/everything/ecore',
             '-Mlib=/var/libraries/lib/perl5' );
sub _cron { my (@a) = @_; return [ @PERL, '/var/everything/cron/' . shift(@a), @a ] }

my $REGISTRY = [
    # --- light, frequent (the cost driver lives here) ---
    { name => 'datastash',         argv => _cron('cron_datastash.pl'),
      type => 'rate', interval => 120,   timeout => 600,  local => 1 },
    { name => 'refresh-rooms',     argv => _cron('cron_refresh_rooms.pl'),
      type => 'rate', interval => 300,   timeout => 120,  local => 1 },

    # --- daily/periodic (rate semantics: every N since last run) ---
    { name => 'datastash-lengthy', argv => _cron('cron_datastash.pl', '--lengthy'),
      type => 'rate', interval => 21600, timeout => 1800, local => 1 },
    { name => 'iqm-recalc',        argv => _cron('cron_iqm_recalculate.pl'),
      type => 'rate', interval => 86400, timeout => 900,  local => 1 },
    { name => 'clean-old-rooms',   argv => _cron('cron_clean_old_rooms.pl'),
      type => 'rate', interval => 86400, timeout => 300,  local => 1 },
    { name => 'writeup-reaper',    argv => _cron('cron_writeup_reaper.pl'),
      type => 'rate', interval => 86400, timeout => 300,  local => 1 },

    # --- wall-clock cron rules ---
    { name => 'chatterbox-cleanup', argv => _cron('cron_clean_cbox.pl'),
      type => 'cron', cron => '50 * * * *', period => 3600,  timeout => 120,  local => 1 },
    { name => 'generate-sitemap',   argv => _cron('cron_generate_sitemap.pl'),
      type => 'cron', cron => '0 0 * * *',  period => 86400, timeout => 1800, local => 1 },
];

sub entries { return $REGISTRY }

sub entry {
    my ( $self, $name ) = @_;
    foreach my $e (@$REGISTRY) { return $e if $e->{name} eq $name }
    return;
}

# expected_period -- the nominal gap between runs, used by the health evaluator
# to decide "overdue". rate -> interval; cron -> the declared period.
sub expected_period {
    my ( $self, $entry ) = @_;
    return $entry->{type} eq 'cron' ? $entry->{period} : $entry->{interval};
}

# due -- should this job fire at $now, given its last run start ($last_run epoch,
# undef/0 if never)? rate: interval elapsed. cron: a scheduled fire has occurred
# since the last run.
sub due {
    my ( $self, $entry, $now, $last_run ) = @_;
    $last_run ||= 0;
    if ( $entry->{type} eq 'cron' ) {
        return $last_run < $self->prev_fire( $entry->{cron}, $now );
    }
    return ( $now - $last_run ) >= $entry->{interval};
}

# prev_fire -- the most recent scheduled epoch <= $now for a 5-field cron expr.
# Minute resolution, UTC (the server runs TZ=+0000). Supports '*' and
# comma-separated integer lists in each field -- all we use, plus headroom.
sub prev_fire {
    my ( $self, $cron, $now ) = @_;
    my $minute = int( $now / 60 ) * 60;
    # Bound the backward scan: 31 days covers every monthly-or-finer expression.
    for ( my $t = $minute ; $t > $minute - 44640 * 60 ; $t -= 60 ) {
        return $t if $self->_cron_match( $cron, $t );
    }
    return 0;
}

sub _cron_match {
    my ( $self, $cron, $epoch ) = @_;
    my @f = split /\s+/, $cron;
    return 0 unless @f == 5;
    my ( $min, $hour, $mday, $mon, $wday ) = ( gmtime $epoch )[ 1, 2, 3, 4, 6 ];
    # cron months are 1-12 (gmtime is 0-11); cron dow is 0-6 Sun=0 (gmtime wday
    # is already 0=Sun..6=Sat). Treat cron '7' as Sunday too.
    my @want = ( $min, $hour, $mday, $mon + 1, $wday );
    for my $i ( 0 .. 4 ) {
        next if $f[$i] eq '*';
        my %ok = map { $_ => 1 } split /,/, $f[$i];
        $ok{0} = 1 if $i == 4 && $ok{7};    # dow 7 == 0 (Sunday)
        return 0 unless $ok{ $want[$i] };
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;
1;
