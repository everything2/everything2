#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::notifications;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");

#############################################################################
# Mock classes
#############################################################################

# Helper: Create a mock request object
package MockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
    sub JSON_POSTDATA { return $_[0]->{_postdata} }
    sub is_guest { return $_[0]->user->is_guest }
}

# Helper: Create a mock user object
package MockUser {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            node_id => $args{node_id},
            title => $args{title},
            NODEDATA => $args{NODEDATA},
            VARS => $args{VARS} // {},
            is_guest_flag => $args{is_guest_flag} // 0,
        };
        return bless $self, $class;
    }
    sub NODEDATA { return $_[0]->{NODEDATA} }
    sub VARS { return $_[0]->{VARS} }
    sub is_guest { return $_[0]->{is_guest_flag} }
}

package main;

#############################################################################
# Helper functions
#############################################################################

sub create_test_notification {
  my ($user_id) = @_;

  my $notification_id = 1;  # Assuming a notification type exists
  my $notified_time = time();

  $DB->sqlInsert('notified', {
    user_id => $user_id,
    notification_id => $notification_id,
    notified_time => $notified_time,
    is_seen => 0,
    args => '{}'
  });

  return $DB->sqlSelect('LAST_INSERT_ID()');
}

# Create API instance
my $api = Everything::API::notifications->new();
ok($api, "Created notifications API instance");

#############################################################################
# Test Cases
#############################################################################

subtest 'Dismiss notification - success' => sub {
  plan tests => 8;

  my $root = $DB->getNodeById(1);
  my $notified_id = create_test_notification(1);  # root's notification

  my $mock_user = MockUser->new(
    node_id => 1,
    title => 'root',
    NODEDATA => { user_id => 1 },
    is_guest_flag => 0
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => { notified_id => $notified_id }
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 200, 'Returns HTTP 200 OK');
  is($data->{success}, 1, 'Returns success flag');
  is($data->{notified_id}, $notified_id, 'Returns notified_id');
  ok(exists $data->{notifications}, 'Returns notifications array');
  ok(ref($data->{notifications}) eq 'ARRAY', 'Notifications is an array');

  # Verify notification structure matches React component expectations
  if (scalar @{$data->{notifications}} > 0) {
    my $first_notif = $data->{notifications}->[0];
    ok(exists $first_notif->{notified_id}, 'Notification has notified_id field');
    ok(exists $first_notif->{html}, 'Notification has html field');
  } else {
    pass('No notifications remaining (expected after dismiss)');
    pass('Skipping html field check');
  }

  # Verify notification was marked as seen
  my $is_seen = $DB->sqlSelect('is_seen', 'notified', "notified_id = $notified_id");
  is($is_seen, 1, 'Notification marked as seen in database');
};

subtest 'Dismiss notification - invalid notified_id' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => 1,
    title => 'root',
    NODEDATA => { user_id => 1 },
    is_guest_flag => 0
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => { notified_id => 'invalid' }
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 400, 'Returns HTTP 400 Bad Request');
  like($data->{error}, qr/notified_id/, 'Error message mentions notified_id');
};

subtest 'Dismiss notification - missing notified_id' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => 1,
    title => 'root',
    NODEDATA => { user_id => 1 },
    is_guest_flag => 0
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {}
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 400, 'Returns HTTP 400 Bad Request');
  like($data->{error}, qr/notified_id/, 'Error message mentions notified_id');
};

subtest 'Dismiss notification - not found' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => 1,
    title => 'root',
    NODEDATA => { user_id => 1 },
    is_guest_flag => 0
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => { notified_id => 99999999 }
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 404, 'Returns HTTP 404 Not Found');
  like($data->{error}, qr/not found/i, 'Error message indicates not found');
};

subtest "Dismiss notification - can't dismiss another user's notification" => sub {
  plan tests => 3;

  # Create notification for guest user
  my $notified_id = create_test_notification(-1);  # guest's notification

  # Try to dismiss as root user
  my $mock_user = MockUser->new(
    node_id => 1,
    title => 'root',
    NODEDATA => { user_id => 1 },
    is_guest_flag => 0
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => { notified_id => $notified_id }
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 403, 'Returns HTTP 403 Forbidden');
  like($data->{error}, qr/cannot dismiss/i, 'Error message indicates permission denied');

  # Verify notification was NOT marked as seen
  my $is_seen = $DB->sqlSelect('is_seen', 'notified', "notified_id = $notified_id");
  is($is_seen, 0, 'Notification still not seen in database');
};

subtest 'Dismiss notification - guest user blocked' => sub {
  plan tests => 1;

  my $notified_id = create_test_notification(-1);

  my $mock_user = MockUser->new(
    node_id => -1,
    title => 'Guest User',
    NODEDATA => { user_id => -1 },
    is_guest_flag => 1
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => { notified_id => $notified_id }
  );

  my ($status, $data) = @{$api->dismiss($mock_request)};

  is($status, 401, 'Guest users return HTTP 401 Unauthorized');
};

done_testing();
