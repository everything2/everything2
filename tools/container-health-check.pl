#!/usr/bin/env perl

# Container Health Check Script for Everything2
# Runs directly in the container without relying on Apache mod_perl
# Designed for ECS container health checks
#
# Usage:
#   ./tools/container-health-check.pl [options]
#
# Options:
#   --detailed    Include detailed system metrics
#   --db          Test database connectivity (default: enabled)
#   --no-db       Skip database connectivity test
#   --timeout N   HTTP timeout in seconds (default: 5)
#   --quiet       Only output on failure
#   --help        Show this help
#
# Exit codes:
#   0 - Healthy
#   1 - Unhealthy
#
# Output: JSON to stdout
# Logging: All health checks logged to CloudWatch in production environments
#
# Health Checks Performed:
#   1. Apache processes running (ps aux)
#   2. HTTP endpoint responsive (curl http://localhost/health.pl)
#   3. Apache server-status (mod_status internal configuration)
#   4. Database connectivity (enabled by default, use --no-db to skip)
#   5. System load (--detailed only)
#   6. Memory usage (--detailed only)
#
# Apache Server Status Data:
#   The script captures complete Apache internal configuration from mod_status,
#   including: ServerVersion, ServerMPM, BusyWorkers, IdleWorkers, Uptime,
#   Total Accesses, ReqPerSec, Scoreboard, Load averages, and more.
#   This data is included in response.apache.server_status for debugging.

use strict;
use warnings;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Time::HiRes qw(time);
use JSON;
use Getopt::Long;

# Parse options
my $detailed = 0;
my $check_db = 1;  # Database checks enabled by default
my $timeout = 5;
my $quiet = 0;
my $help = 0;

GetOptions(
    'detailed' => \$detailed,
    'db!' => \$check_db,
    'timeout=i' => \$timeout,
    'quiet' => \$quiet,
    'help' => \$help,
) or die "Error parsing options. Use --help for usage.\n";

if ($help) {
    print <<'HELP';
Container Health Check Script for Everything2

Usage: container-health-check.pl [options]

Options:
  --detailed    Include detailed system metrics
  --db          Test database connectivity (default: enabled)
  --no-db       Skip database connectivity test
  --timeout N   HTTP timeout in seconds (default: 5)
  --quiet       Only output on failure
  --help        Show this help

Exit codes:
  0 - Healthy
  1 - Unhealthy

Output: JSON to stdout
Logging: All health checks logged to CloudWatch in production environments

Health Checks Performed:
  1. Apache processes running (ps aux)
  2. HTTP endpoint responsive (curl http://localhost/health.pl)
  3. Apache server-status (mod_status internal configuration)
  4. Database connectivity (enabled by default, use --no-db to skip)
  5. System load (--detailed only)
  6. Memory usage (--detailed only)

Apache Server Status Data:
  The script captures complete Apache internal configuration from mod_status,
  including: ServerVersion, ServerMPM, BusyWorkers, IdleWorkers, Uptime,
  Total Accesses, ReqPerSec, Scoreboard, Load averages, and more.
  This data is included in response.apache.server_status for debugging.
HELP
    exit 0;
}

# Database checks are enabled by default
# Detailed mode enables additional system metrics only when explicitly requested

# Detect production environment (CloudWatch logging)
my $is_production = ($ENV{E2_DOCKER} || '') ne '' && ($ENV{E2_DEVELOPMENT} || '') eq '';
my $cloudwatch_log_group = '/aws/fargate/e2-health-check';

my $start_time = time();
my $response = {
    status => 'ok',
    timestamp => time(),
    version => 'container-health-check-v1',
    checks => {},
};
my $all_ok = 1;

# Check 1: Apache processes running
my $apache_procs = 0;
if (open(my $fh, '-|', 'ps aux')) {
    while (my $line = <$fh>) {
        $apache_procs++ if $line =~ /apache2/i && $line !~ /^\s*$/;
    }
    close($fh);
}

if ($apache_procs > 0) {
    $response->{checks}->{apache_processes} = 'ok';
} else {
    $response->{checks}->{apache_processes} = 'failed';
    $response->{checks}->{apache_processes_error} = 'No Apache processes found';
    $all_ok = 0;
}

# Check 2: HTTP endpoint responsive
my $http_ok = 0;
my $http_status = 0;
my $http_error = '';

if (open(my $fh, '-|', "curl -f -s -m $timeout -o /dev/null -w '%{http_code}' http://localhost/health.pl 2>&1")) {
    my $output = <$fh>;
    close($fh);

    if ($output && $output =~ /^(\d+)$/) {
        $http_status = $1;
        $http_ok = ($http_status == 200);
    } else {
        $http_error = $output || 'No response';
    }
} else {
    $http_error = "Failed to execute curl: $!";
}

if ($http_ok) {
    $response->{checks}->{apache_http} = 'ok';
    $response->{checks}->{apache_http_status} = $http_status;
} else {
    $response->{checks}->{apache_http} = 'failed';
    $response->{checks}->{apache_http_status} = $http_status if $http_status;
    $response->{checks}->{apache_http_error} = $http_error if $http_error;
    $all_ok = 0;
}

# Check 3: Apache server-status (always check for debugging)
$response->{apache} = {
    process_count => $apache_procs,
};

eval {
    if (open(my $fh, '-|', "curl -s -m 1 http://localhost/server-status?auto 2>/dev/null")) {
        my %status;
        while (my $line = <$fh>) {
            chomp($line);
            if ($line =~ /^(.+?):\s*(.+)$/) {
                my $key = $1;
                my $val = $2;
                # Handle multi-word keys (e.g., "Total Accesses")
                $key =~ s/\s+/_/g;
                $status{$key} = $val;
            }
        }
        close($fh);

        # Extract key metrics for easy access
        if (exists $status{BusyWorkers}) {
            $response->{apache}->{busy_workers} = $status{BusyWorkers} + 0;
        }
        if (exists $status{IdleWorkers}) {
            $response->{apache}->{idle_workers} = $status{IdleWorkers} + 0;
        }
        if (exists $status{Uptime}) {
            $response->{apache}->{uptime_seconds} = $status{Uptime} + 0;
        }
        if (exists $status{Total_Accesses}) {
            $response->{apache}->{total_accesses} = $status{Total_Accesses} + 0;
        }
        if (exists $status{ReqPerSec}) {
            $response->{apache}->{requests_per_sec} = sprintf("%.2f", $status{ReqPerSec});
        }

        # Include complete server-status data for debugging
        $response->{apache}->{server_status} = \%status;
    }
};
# Silently ignore server-status errors - don't fail health check if mod_status unavailable

# Detailed health checks
if ($detailed) {
    # System load
    eval {
        if (open(my $fh, '<', '/proc/loadavg')) {
            my $loadavg = <$fh>;
            close($fh);

            if ($loadavg =~ /^([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\/(\d+)/) {
                $response->{system} = {
                    load_1min => $1 + 0,
                    load_5min => $2 + 0,
                    load_15min => $3 + 0,
                    running_processes => $4 + 0,
                    total_processes => $5 + 0,
                };
            }
        }
    };

    # Memory usage
    eval {
        if (open(my $fh, '<', '/proc/meminfo')) {
            my %mem;
            while (my $line = <$fh>) {
                if ($line =~ /^(\w+):\s+(\d+)/) {
                    $mem{$1} = $2;
                }
            }
            close($fh);

            if ($mem{MemTotal} && $mem{MemAvailable}) {
                my $used = $mem{MemTotal} - $mem{MemAvailable};
                my $used_pct = ($used / $mem{MemTotal}) * 100;

                $response->{memory} = {
                    total_kb => $mem{MemTotal},
                    available_kb => $mem{MemAvailable},
                    used_kb => $used,
                    used_percent => sprintf("%.1f", $used_pct),
                };
            }
        }
    };

    # Apache process details already captured in basic checks above
    # Additional detailed system metrics only in detailed mode
}

# Database check
if ($check_db) {
    eval {
        require DBI;

        my $dbserv = $ENV{E2_DBSERV} || 'localhost';
        my $dbname = 'everything';
        my $dbuser = 'everyuser';

        # Read database password
        my $dbpass = '';
        if (open(my $fh, '<', '/etc/everything/database_password_secret')) {
            local $/ = undef;
            $dbpass = <$fh>;
            close($fh);
            chomp($dbpass);
        }

        # Try to connect with minimal timeout
        my $dbh = DBI->connect(
            "DBI:mysql:database=$dbname;host=$dbserv",
            $dbuser,
            $dbpass,
            {
                RaiseError => 1,
                PrintError => 0,
                mysql_connect_timeout => 2,
            }
        );

        if ($dbh) {
            my $sth = $dbh->prepare("SELECT 1");
            $sth->execute();
            my ($result) = $sth->fetchrow_array();

            if ($result == 1) {
                $response->{checks}->{database} = 'ok';
            } else {
                $response->{checks}->{database} = 'query_failed';
                $all_ok = 0;
            }

            $sth->finish();
            $dbh->disconnect();
        } else {
            $response->{checks}->{database} = 'connection_failed';
            $all_ok = 0;
        }
    };

    if ($@) {
        $response->{checks}->{database} = 'error';
        $response->{checks}->{database_error} = substr($@, 0, 200);
        $all_ok = 0;
    }
}

# Add response time
my $elapsed = time() - $start_time;
$response->{response_time_ms} = sprintf("%.2f", $elapsed * 1000);

# Set overall status
if (!$all_ok) {
    $response->{status} = 'unhealthy';
}

# CloudWatch logging in production
if ($is_production) {
    eval {
        # Get hostname for log stream name
        my $hostname = `hostname`;
        chomp($hostname);
        my $log_stream = "container-health-$hostname";

        # Create JSON log event for CloudWatch
        my $log_event = {
            status => $response->{status},
            response_time_ms => $response->{response_time_ms} + 0,
            timestamp => $response->{timestamp},
            checks => $response->{checks},
        };

        # Include system metrics if available
        if ($response->{system}) {
            $log_event->{system} = $response->{system};
        }
        if ($response->{memory}) {
            $log_event->{memory} = $response->{memory};
        }
        if ($response->{apache}) {
            $log_event->{apache} = $response->{apache};
        }

        my $log_message = JSON::encode_json($log_event);

        # Create log stream if it doesn't exist (ignore errors if it already exists)
        system("aws logs create-log-stream --log-group-name '$cloudwatch_log_group' --log-stream-name '$log_stream' 2>/dev/null");

        # Put log events
        my $timestamp_ms = int($response->{timestamp} * 1000);
        my $log_events = JSON::encode_json([{
            timestamp => $timestamp_ms,
            message => $log_message
        }]);

        # Use a background process to avoid blocking the health check response
        system("aws logs put-log-events --log-group-name '$cloudwatch_log_group' --log-stream-name '$log_stream' --log-events '$log_events' >/dev/null 2>&1 &");
    };
    # Silently ignore logging errors - don't fail health check due to logging issues
}

# Output JSON
if (!$quiet || !$all_ok) {
    print JSON::encode_json($response) . "\n";
}

# Exit with appropriate code
exit($all_ok ? 0 : 1);
