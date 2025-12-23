package Everything::API::client_errors;

use Moose;
use namespace::autoclean;
use JSON;
use Encode qw(decode_utf8);
use Paws;
use Try::Tiny;
use Readonly;
extends 'Everything::API';

=head1 NAME

Everything::API::client_errors - Client-side error reporting API

=head1 DESCRIPTION

Receives and logs error reports from client-side JavaScript when users
encounter problems. This helps debug issues that don't appear in server logs.

In production, errors are written to CloudWatch Logs (/aws/e2/client-errors).
In development, errors are written via devLog.

=head1 ENDPOINTS

=head2 POST /api/client_errors

Report a client-side error.

Request body:
{
  "error_type": "api_error|js_error|network_error",
  "message": "Error message",
  "context": {
    "url": "current page URL",
    "action": "what user was doing",
    "request_url": "API endpoint that failed (if applicable)",
    "response_status": 200,
    "response_body": "response content (truncated)"
  },
  "stack": "JavaScript stack trace (optional)",
  "user_agent": "browser UA string"
}

=cut

# CloudWatch Logs configuration
Readonly my $LOG_GROUP_NAME => '/aws/e2/client-errors';
Readonly my $LOG_STREAM_PREFIX => 'client-errors-';

# Rate limiting: max errors per IP per time window
Readonly my $RATE_LIMIT_MAX => 10;        # max 10 errors
Readonly my $RATE_LIMIT_WINDOW => 60;     # per 60 seconds

# In-memory rate limit tracking (resets on server restart, which is fine)
my %rate_limit_cache;

sub routes {
    return {
        '/' => 'report_error'
    };
}

sub report_error {
    my ($self, $REQUEST) = @_;

    # Only accept POST
    my $method = lc($REQUEST->request_method());
    unless ($method eq 'post') {
        return [
            $self->HTTP_UNIMPLEMENTED,
            { success => 0, error => 'method_not_allowed' }
        ];
    }

    # Get client IP early for rate limiting
    my $client_ip = $REQUEST->cgi->http('X-Forwarded-For')
                 || $REQUEST->cgi->remote_addr()
                 || 'unknown';
    # Take first IP if comma-separated list
    $client_ip = (split(/\s*,\s*/, $client_ip))[0] || 'unknown';

    # Check rate limit
    if ($self->_is_rate_limited($client_ip)) {
        return [
            $self->HTTP_OK,  # Return 200 so bots don't know they're blocked
            { success => 1, rate_limited => 1 }
        ];
    }

    my $postdata = $REQUEST->POSTDATA;
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };

    unless ($json_ok && $data) {
        return [
            $self->HTTP_BAD_REQUEST,
            { success => 0, error => 'invalid_json' }
        ];
    }

    # Validate required fields
    my $error_type = $data->{error_type} || 'unknown';
    my $message = $data->{message} || '';

    unless ($message) {
        return [
            $self->HTTP_BAD_REQUEST,
            { success => 0, error => 'message_required' }
        ];
    }

    # Sanitize and truncate fields
    $error_type = substr($error_type, 0, 50);
    $message = substr($message, 0, 2000);

    my $context = $data->{context} || {};
    my $stack = $data->{stack} || '';
    $stack = substr($stack, 0, 4000);

    my $user_agent = $data->{user_agent} || $REQUEST->cgi->user_agent() || '';
    $user_agent = substr($user_agent, 0, 500);

    # Get user info
    my $user = $REQUEST->user;
    my $user_id = $user->is_guest ? 0 : $user->node_id;
    my $username = $user->is_guest ? 'guest' : $user->title;

    # Truncate client_ip for storage
    $client_ip = substr($client_ip, 0, 45);

    # Build log entry
    my $log_entry = {
        timestamp => time() * 1000, # milliseconds for CloudWatch
        error_type => $error_type,
        message => $message,
        context => $context,
        stack => $stack,
        user_id => $user_id,
        username => $username,
        user_agent => $user_agent,
        client_ip => $client_ip,
        build_id => $self->CONF->last_commit_short || 'unknown'
    };

    # Log based on environment
    if ($self->CONF->is_production) {
        $self->_log_to_cloudwatch($log_entry);
    } else {
        $self->_log_to_devlog($log_entry);
    }

    return [
        $self->HTTP_OK,
        { success => 1 }
    ];
}

sub _is_rate_limited {
    my ($self, $ip) = @_;

    my $now = time();
    my $window_start = $now - $RATE_LIMIT_WINDOW;

    # Clean up old entries for this IP
    if (exists $rate_limit_cache{$ip}) {
        $rate_limit_cache{$ip} = [
            grep { $_ > $window_start } @{$rate_limit_cache{$ip}}
        ];
    } else {
        $rate_limit_cache{$ip} = [];
    }

    # Check if over limit
    if (scalar(@{$rate_limit_cache{$ip}}) >= $RATE_LIMIT_MAX) {
        return 1;  # Rate limited
    }

    # Record this request
    push @{$rate_limit_cache{$ip}}, $now;

    # Periodic cleanup of stale IPs (every ~100 requests, clean IPs with no recent activity)
    if (rand() < 0.01) {
        for my $cached_ip (keys %rate_limit_cache) {
            my @recent = grep { $_ > $window_start } @{$rate_limit_cache{$cached_ip}};
            if (@recent == 0) {
                delete $rate_limit_cache{$cached_ip};
            }
        }
    }

    return 0;  # Not rate limited
}

sub _log_to_devlog {
    my ($self, $log_entry) = @_;

    my $formatted = sprintf(
        "CLIENT ERROR [%s] user=%s ip=%s: %s | context=%s",
        $log_entry->{error_type},
        $log_entry->{username},
        $log_entry->{client_ip},
        $log_entry->{message},
        JSON::encode_json($log_entry->{context})
    );

    $self->devLog($formatted);

    return;
}

sub _log_to_cloudwatch {
    my ($self, $log_entry) = @_;

    try {
        my $logs = Paws->service('CloudWatchLogs', region => $self->CONF->current_region);

        # Use date-based log stream name
        my ($sec, $min, $hour, $mday, $mon, $year) = gmtime();
        my $stream_name = sprintf("%s%04d-%02d-%02d",
            $LOG_STREAM_PREFIX, $year + 1900, $mon + 1, $mday);

        # Ensure log stream exists (create if not)
        try {
            $logs->CreateLogStream(
                logGroupName => $LOG_GROUP_NAME,
                logStreamName => $stream_name
            );
        } catch {
            # Stream already exists - that's fine
        };

        # Get sequence token for the stream
        my $streams = $logs->DescribeLogStreams(
            logGroupName => $LOG_GROUP_NAME,
            logStreamNamePrefix => $stream_name,
            limit => 1
        );

        my $sequence_token;
        if ($streams->logStreams && @{$streams->logStreams}) {
            $sequence_token = $streams->logStreams->[0]->uploadSequenceToken;
        }

        # Put log event
        my $log_message = JSON::encode_json($log_entry);

        my %put_params = (
            logGroupName => $LOG_GROUP_NAME,
            logStreamName => $stream_name,
            logEvents => [{
                timestamp => $log_entry->{timestamp},
                message => $log_message
            }]
        );

        # Include sequence token if we have one
        $put_params{sequenceToken} = $sequence_token if $sequence_token;

        $logs->PutLogEvents(%put_params);

    } catch {
        # Log failure to devLog as fallback
        $self->devLog("Failed to write client error to CloudWatch: $_");
        $self->_log_to_devlog($log_entry);
    };

    return;
}

# Allow guests to report errors (they're the ones most likely to have problems)

__PACKAGE__->meta->make_immutable;

1;
