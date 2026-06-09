package Everything::HealthCheck;

use strict;
use warnings;
use JSON ();
use Time::HiRes ();

## no critic (ProhibitMagicNumbers RequireExtendedFormatting RequireDotMatchAnything RequireLineBoundaryMatching ProhibitEscapedCharacters)

=head1 NAME

Everything::HealthCheck - PSGI health-check app for ECS/ELB

=head1 DESCRIPTION

The PSGI rewrite of the old C<www/health.pl> (a mod_perl script that cannot run
under Starman/mpm_event). Mounted by app.psgi for C</health> and C</health.pl>.

  GET /health            -> 200 {"status":"ok",...}            (liveness; fast, no DB)
  GET /health?detailed=1 -> + system load + memory             (monitoring)
  GET /health?db=1       -> + DB connectivity; 503 if unhealthy (readiness)

C<to_app> returns a PSGI coderef. The basic path is deliberately cheap and
dependency-free so it stays a true liveness signal (a DB hiccup must NOT fail the
ELB health check and recycle every task). The C<?db=1> prober is a
B<framework-free> direct DBI connect as the real app DB user, so it tests the
actual auth path even when the app framework itself is degraded (#4215).

Unit-tested in t/127 by calling C<handle> with a synthetic PSGI env.

=cut

# Returns a PSGI application coderef.
sub to_app {
    my ($class) = @_;
    return sub { return $class->handle( $_[0] ) };
}

sub handle {
    my ( $class, $env ) = @_;
    my $start = Time::HiRes::time();

    my %q       = _parse_query( $env->{QUERY_STRING} // '' );
    my $deep    = $q{detailed} || $q{db};
    my $do_db   = $q{db};

    my $response = {
        status    => 'ok',
        timestamp => time(),
        version   => 'health-check-v2',
        backend   => 'psgi',
    };
    my $http_status = 200;

    if ($deep) {
        $response->{checks} = { app => 'ok' };
        if ( my $sys = _loadavg() ) { $response->{system} = $sys }
        if ( my $mem = _meminfo() ) { $response->{memory} = $mem }

        if ($do_db) {
            my ( $ok, $detail ) = _check_db();
            $response->{checks}{database} = $detail;
            unless ($ok) {
                $response->{status} = 'unhealthy';
                $http_status = 503;
            }
        }

        $response->{response_ms} = sprintf '%.1f', ( Time::HiRes::time() - $start ) * 1000;
    }

    my $json = JSON->new->canonical->encode($response);
    return [
        $http_status,
        [   'Content-Type'  => 'application/json',
            'Cache-Control' => 'no-cache, no-store, must-revalidate',
            'Pragma'        => 'no-cache',
            'Expires'       => '0',
        ],
        [$json],
    ];
}

# Minimal query-string parser (no CGI / Plack::Request -- the health app must
# stay independent of the request stack).
sub _parse_query {
    my ($qs) = @_;
    my %p;
    for my $pair ( split /[&;]/, $qs ) {
        my ( $k, $v ) = split /=/, $pair, 2;
        next unless defined $k && length $k;
        $v = defined $v ? $v : '';
        $v =~ tr/+/ /;
        $v =~ s/%([0-9a-fA-F]{2})/chr hex $1/ge;
        $p{$k} = $v;
    }
    return %p;
}

sub _loadavg {
    open my $fh, '<', '/proc/loadavg' or return;
    my $line = <$fh>;
    close $fh;
    return unless defined $line;
    return unless $line =~ /^([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\/(\d+)/;
    return {
        load_1min         => $1 + 0,
        load_5min         => $2 + 0,
        load_15min        => $3 + 0,
        running_processes => $4 + 0,
        total_processes   => $5 + 0,
    };
}

sub _meminfo {
    open my $fh, '<', '/proc/meminfo' or return;
    my %mem;
    while ( my $l = <$fh> ) {
        $mem{$1} = $2 if $l =~ /^(\w+):\s+(\d+)/;
    }
    close $fh;
    return unless $mem{MemTotal} && defined $mem{MemAvailable};
    my $used = $mem{MemTotal} - $mem{MemAvailable};
    return {
        total_kb     => $mem{MemTotal},
        available_kb => $mem{MemAvailable},
        used_kb      => $used,
        used_percent => sprintf( '%.1f', ( $used / $mem{MemTotal} ) * 100 ),
    };
}

# Framework-free DB prober (#4215): connect as the real app DB user
# (everyuser / production.json's everyuser after the auth-plugin migration) using
# the password secret, over SSL, with a short connect timeout, then SELECT 1.
# Independent of the app framework on purpose -- it tests the true auth path.
sub _check_db {
    my ( $ok, $detail ) = ( 0, 'error' );
    eval {
        require DBI;

        my $dbserv = $ENV{E2_DBSERV} || 'localhost';
        my $dbname = 'everything';

        my $dbuser = 'everyuser';
        if ( ( $ENV{E2_DOCKER} || '' ) ne 'development' ) {
            if ( open my $cf, '<', '/var/everything/etc/production.json' ) {
                local $/ = undef;
                my $j = eval { JSON::decode_json(<$cf>) };
                close $cf;
                $dbuser = $j->{everyuser} if $j && $j->{everyuser};
            }
        }

        my $dbpass = '';
        if ( open my $fh, '<', '/etc/everything/database_password_secret' ) {
            local $/ = undef;
            $dbpass = <$fh>;
            close $fh;
            chomp $dbpass;
        }

        my $dbh = DBI->connect(
            "DBI:mysql:database=$dbname;host=$dbserv;mysql_ssl=1;mysql_get_server_pubkey=1",
            $dbuser, $dbpass,
            { RaiseError => 1, PrintError => 0, mysql_connect_timeout => 2 },
        );

        if ($dbh) {
            my ($one) = $dbh->selectrow_array('SELECT 1');
            $dbh->disconnect;
            if ( defined $one && $one == 1 ) { $ok = 1; $detail = 'ok' }
            else                             { $detail = 'query_failed' }
        }
        else {
            $detail = 'connection_failed';
        }
        1;
    } or do { $detail = 'error' };

    return ( $ok, $detail );
}

1;
