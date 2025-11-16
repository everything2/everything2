#!/usr/bin/perl -w

# Health Check Endpoint for Everything2
# Designed for ECS/ELB health checks - returns quickly with minimal overhead
#
# Query parameters:
#   ?detailed=1  - Include detailed health status with system metrics
#   ?db=1        - Test database connectivity (implies detailed, slower)
#
# Returns:
#   200 OK - Application is healthy
#   503 Service Unavailable - Application is unhealthy
#
# Response format:
#   Basic: {"status":"ok","timestamp":1234567890}
#   Detailed: {"status":"ok","timestamp":1234567890,"checks":{"apache":"ok"},
#              "system":{...},"memory":{...},"apache":{...}}
#   Database: {"status":"ok","timestamp":1234567890,"checks":{"apache":"ok","database":"ok"},
#              "system":{...},"memory":{...},"apache":{...}}
#
# System metrics (when detailed=1 or db=1):
#   - System load: 1/5/15 minute load averages, process counts
#   - Memory usage: total, available, used (KB and percentage)
#   - Apache metrics: process count, worker status, request stats, uptime
#     (from mod_status: busy/idle workers, total accesses, requests/sec,
#      worker states breakdown, scoreboard summary)
#
# Logging:
#   - Local file: /var/log/everything/health-check.log (failures and slow responses)
#   - CloudWatch Logs: /aws/fargate/health-check-awslogs (failures and slow responses)
#   - Only logs when health check fails or takes > 1 second to avoid log spam

use strict;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK SERVER_ERROR HTTP_SERVICE_UNAVAILABLE);
use CGI;
use JSON;
use Time::HiRes qw(time);

my $r = shift;
my $q = CGI->new;

# Set response headers
$r->content_type('application/json');
$r->headers_out->set('Cache-Control' => 'no-cache, no-store, must-revalidate');
$r->headers_out->set('Pragma' => 'no-cache');
$r->headers_out->set('Expires' => '0');

my $start_time = time();
my $response = {
    status => 'ok',
    timestamp => time(),
    version => 'health-check-v1'
};

my $detailed = $q->param('detailed') || 0;
my $check_db = $q->param('db') || 0;
my $all_ok = 1;

# Health check logging (only log failures or slow responses)
my $log_health = 1;  # Enable health check logging
my $slow_threshold = 1.0;  # Log if health check takes > 1 second
my $log_file = '/var/log/everything/health-check.log';
my $cloudwatch_log_group = '/aws/fargate/e2-health-check';
my $cloudwatch_enabled = 0;  # Enable CloudWatch Logs (disabled until infrastructure is deployed)

# Detailed health check
if ($detailed || $check_db) {
    $response->{checks} = {};

    # Apache is obviously working if we got here
    $response->{checks}->{apache} = 'ok';

    # System load information (from /proc/loadavg)
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
                    total_processes => $5 + 0
                };
            }
        }
    };

    # Memory usage (from /proc/meminfo)
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
                    used_percent => sprintf("%.1f", $used_pct)
                };
            }
        }
    };

    # Apache process/request information
    eval {
        # Count Apache processes
        my $apache_procs = 0;
        if (open(my $fh, '-|', 'ps aux')) {
            while (my $line = <$fh>) {
                $apache_procs++ if $line =~ /apache2/i && $line !~ /^\s*$/;
            }
            close($fh);
        }

        $response->{apache} = {
            process_count => $apache_procs
        };

        # Get detailed Apache status from mod_status
        # Using curl instead of LWP::UserAgent for better reliability
        if (open(my $fh, '-|', 'curl -s -m 1 http://localhost/server-status?auto 2>/dev/null')) {
            my %status;
            while (my $line = <$fh>) {
                chomp($line);
                if ($line =~ /^(\w+):\s*(.+)$/) {
                    $status{$1} = $2;
                }
            }
            close($fh);

            # Add worker information
            if (exists $status{BusyWorkers}) {
                $response->{apache}->{busy_workers} = $status{BusyWorkers} + 0;
            }
            if (exists $status{IdleWorkers}) {
                $response->{apache}->{idle_workers} = $status{IdleWorkers} + 0;
            }

            # Add request statistics
            if (exists $status{Total accesses}) {
                $response->{apache}->{total_accesses} = $status{'Total accesses'} + 0;
            }
            if (exists $status{ReqPerSec}) {
                $response->{apache}->{requests_per_sec} = sprintf("%.2f", $status{ReqPerSec});
            }

            # Add scoreboard summary (worker states)
            if (exists $status{Scoreboard}) {
                my $scoreboard = $status{Scoreboard};
                my %worker_states = (
                    waiting => ($scoreboard =~ tr/_/_/),       # Waiting for Connection
                    starting => ($scoreboard =~ tr/S/S/),      # Starting up
                    reading => ($scoreboard =~ tr/R/R/),       # Reading Request
                    sending => ($scoreboard =~ tr/W/W/),       # Sending Reply
                    keepalive => ($scoreboard =~ tr/K/K/),     # Keepalive (read)
                    dns => ($scoreboard =~ tr/D/D/),           # DNS Lookup
                    closing => ($scoreboard =~ tr/C/C/),       # Closing connection
                    logging => ($scoreboard =~ tr/L/L/),       # Logging
                    finishing => ($scoreboard =~ tr/G/G/),     # Gracefully finishing
                    idle_cleanup => ($scoreboard =~ tr/I/I/),  # Idle cleanup
                    open_slot => ($scoreboard =~ tr/\./\./),   # Open slot (no process)
                );

                $response->{apache}->{worker_states} = \%worker_states;
                $response->{apache}->{total_slots} = length($scoreboard);
            }

            # Add uptime if available
            if (exists $status{Uptime}) {
                $response->{apache}->{uptime_seconds} = $status{Uptime} + 0;
            }
        }
    };

    # Check database connectivity if requested
    if ($check_db) {
        eval {
            # Only load DBI if we need it (lighter weight for basic checks)
            require DBI;

            my $dbserv = $ENV{E2_DBSERV} || 'localhost';
            my $dbname = 'everything';
            my $dbuser = 'everyuser';

            # Read database password from configuration file
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
                    mysql_connect_timeout => 2,  # 2 second timeout
                }
            );

            if ($dbh) {
                # Simple query to verify DB is responsive
                my $sth = $dbh->prepare("SELECT 1");
                $sth->execute();
                my ($result) = $sth->fetchrow_array();

                if ($result == 1) {
                    $response->{checks}->{database} = 'ok';
                } else {
                    $response->{checks}->{database} = 'query_failed';
                    $all_ok = 0;
                }

                $dbh->disconnect();
            } else {
                $response->{checks}->{database} = 'connection_failed';
                $all_ok = 0;
            }
        };

        if ($@) {
            $response->{checks}->{database} = 'error';
            $response->{checks}->{database_error} = substr($@, 0, 200);  # Truncate error message
            $all_ok = 0;
        }
    }

    # Add response time
    my $elapsed = time() - $start_time;
    $response->{response_time_ms} = sprintf("%.2f", $elapsed * 1000);
}

# Set status based on health
if (!$all_ok) {
    $response->{status} = 'unhealthy';
    $r->status(Apache2::Const::HTTP_SERVICE_UNAVAILABLE);
} else {
    $r->status(Apache2::Const::OK);
}

# Health check logging - only log failures or slow responses to avoid log spam
if ($log_health) {
    my $elapsed = time() - $start_time;
    my $should_log = 0;
    my $log_reason = '';

    if (!$all_ok) {
        $should_log = 1;
        $log_reason = 'FAILED';
    } elsif ($elapsed > $slow_threshold) {
        $should_log = 1;
        $log_reason = 'SLOW';
    }

    if ($should_log) {
        eval {
            my $timestamp = scalar(localtime());
            my $elapsed_ms = sprintf("%.2f", $elapsed * 1000);
            my $status_code = $all_ok ? 200 : 503;
            my $details = '';

            if ($response->{checks}) {
                $details = ' checks=' . JSON::encode_json($response->{checks});
            }

            my $log_line = "[$timestamp] $log_reason status=$status_code time=${elapsed_ms}ms$details\n";

            # Append to local log file (creates if doesn't exist)
            if (open(my $fh, '>>', $log_file)) {
                print $fh $log_line;
                close($fh);
            }

            # Also send to CloudWatch Logs if enabled
            if ($cloudwatch_enabled) {
                # Get hostname for log stream name
                my $hostname = `hostname`;
                chomp($hostname);
                my $log_stream = "health-check-$hostname";

                # Create JSON log event for CloudWatch
                my $log_event = {
                    reason => $log_reason,
                    status_code => $status_code,
                    response_time_ms => $elapsed_ms + 0,
                    timestamp => $response->{timestamp},
                };

                if ($response->{checks}) {
                    $log_event->{checks} = $response->{checks};
                }
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

                # Write to CloudWatch Logs using AWS CLI
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
            }
        };
        # Silently ignore logging errors - don't fail health check due to logging issues
    }
}

# Send response
print JSON::encode_json($response);

return Apache2::Const::OK;
