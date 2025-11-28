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
use Everything::API::nodenotes;
use Everything::API::notifications;
use JSON;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");

# Get test users - genericeditor (editor permission) will add note to root's writeup  
my $root = $DB->getNode('root', 'user');
ok($root, 'Got root user');

my $genericeditor = $DB->getNode('genericeditor', 'user');
ok($genericeditor, 'Got genericeditor user');

# Get nodenote notification
my $nodenote_notification = $DB->getNode('nodenote', 'notification');
ok($nodenote_notification, 'Got nodenote notification type');

# Store writeup ID for tests
my $test_writeup_id;

# Helper: Create mock REQUEST object for API testing
package MockRequest {
  sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
  }
  sub user { return $_[0]->{user} }
  sub is_guest { return $_[0]->{user}->is_guest }
  sub POSTDATA {
    my $self = shift;
    return undef unless $self->{_postdata};
    require JSON;
    require Encode;
    my $json_string = JSON->new->encode($self->{_postdata});
    return Encode::encode_utf8($json_string);
  }
  sub JSON_POSTDATA { return $_[0]->{_postdata} }
}

# Helper: Create mock user object (from chatroom test)
package MockUser {
  sub new {
    my ($class, %args) = @_;
    if ($args{real_node}) {
      my $self = $args{real_node};
      bless $self, $class;
      $self->{_is_admin_override} = $args{is_admin_flag} if exists $args{is_admin_flag};
      $self->{_is_editor_override} = $args{is_editor_flag} if exists $args{is_editor_flag};
      return $self;
    }
    my $self = {
      node_id => $args{node_id},
      title => $args{title},
      is_admin_flag => $args{is_admin_flag} // 0,
      is_editor_flag => $args{is_editor_flag} // 0,
    };
    return bless $self, $class;
  }
  sub node_id { return $_[0]->{node_id} }
  sub title { return $_[0]->{title} }
  sub is_guest { return 0 }
  sub is_admin { return exists $_[0]->{_is_admin_override} ? $_[0]->{_is_admin_override} : ($_[0]->{is_admin_flag} // 0) }
  sub is_editor { return exists $_[0]->{_is_editor_override} ? $_[0]->{_is_editor_override} : ($_[0]->{is_editor_flag} // 0) }
  sub NODEDATA { return $_[0] }
  # VARS method: Return cached VARS if available, otherwise get from DB
  sub VARS {
    my $self = shift;
    unless ($self->{_cached_VARS}) {
      # Use global $DB and $APP from test
      require Everything;
      $self->{_cached_VARS} = Everything::getVars($self);
    }
    return $self->{_cached_VARS};
  }
}

package main;

subtest 'Subscribe root to node note notifications' => sub {
  plan tests => 5;
  my $VARS = $APP->getVars($root);
  ok($VARS, 'Got root VARS');
  my $settings = {};
  if ($VARS->{settings}) {
    $settings = decode_json($VARS->{settings});
  }
  $settings->{notifications} = $settings->{notifications} || {};
  $settings->{notifications}->{$nodenote_notification->{node_id}} = 1;
  $VARS->{settings} = encode_json($settings);
  Everything::setVars($root, $VARS);
  my $updated_VARS = $APP->getVars($root);
  ok($updated_VARS->{settings}, 'Settings saved to VARS');
  my $updated_settings = decode_json($updated_VARS->{settings});
  ok($updated_settings->{notifications}, 'Notifications hash exists');
  ok($updated_settings->{notifications}->{$nodenote_notification->{node_id}}, 'Nodenote notification subscribed');
  is($updated_settings->{notifications}->{$nodenote_notification->{node_id}}, 1, 'Subscription value is 1');
};

subtest 'Find a writeup owned by root' => sub {
  plan tests => 3;
  my $writeup_id = $DB->sqlSelect('writeup_id', 'writeup JOIN node ON writeup.writeup_id = node.node_id', "node.author_user=$root->{user_id}", 'LIMIT 1');
  ok($writeup_id, 'Found a writeup by root');
  $test_writeup_id = $writeup_id;
  ok($test_writeup_id, 'Stored writeup_id for testing');
  cmp_ok($test_writeup_id, '>', 0, 'Writeup ID is positive');
};

subtest 'Clear previous notifications' => sub {
  plan tests => 1;
  # Clear broadcast notifications (user_id = notification_id)
  $DB->sqlDelete('notified', "user_id=$nodenote_notification->{node_id} AND notification_id=$nodenote_notification->{node_id}");
  my $count = $DB->sqlSelect('COUNT(*)', 'notified', "user_id=$nodenote_notification->{node_id} AND notification_id=$nodenote_notification->{node_id}");
  cmp_ok($count, '==', 0, 'Previous broadcast notifications cleared');
};

subtest 'Create node note via API and verify notification' => sub {
  plan tests => 11;
  my $writeup_node = $DB->getNodeById($test_writeup_id);
  ok($writeup_node, 'Got writeup node');
  is($writeup_node->{author_user}, $root->{user_id}, 'Writeup belongs to root');

  my $editor_user = MockUser->new(real_node => $genericeditor, is_editor_flag => 1);
  my $note_text = "API test note - " . time();
  my $request = MockRequest->new(user => $editor_user, _postdata => { notetext => $note_text });

  my $api = Everything::API::nodenotes->new(DB => $DB, APP => $APP);
  my ($status, $response) = @{$api->add_note($request, $test_writeup_id)};

  is($status, 200, 'API call succeeded (HTTP 200)');
  ok($response->{notes}, 'API response contains notes');

  # Verify broadcast notification was created (user_id = notification_id for broadcast)
  # Root should see it because root is subscribed to nodenote notifications
  # (not because root owns the writeup - writeup owners are NOT notified)
  my $notification = $DB->sqlSelectHashref('*', 'notified', "user_id=$nodenote_notification->{node_id} AND notification_id=$nodenote_notification->{node_id}", 'ORDER BY notified_id DESC LIMIT 1');
  ok($notification, 'Broadcast notification created');
  is($notification->{user_id}, $nodenote_notification->{node_id}, 'Notification user_id equals notification_id (broadcast pattern)');
  is($notification->{notification_id}, $nodenote_notification->{node_id}, 'Notification type is nodenote');
  ok($notification->{args}, 'Notification has args');

  my $args = decode_json($notification->{args});
  is($args->{node_id}, $test_writeup_id, 'Notification args contains correct node_id');

  my $notifications_api = Everything::API::notifications->new(DB => $DB, APP => $APP);
  my $root_user = MockUser->new(real_node => $root);
  my $root_request = MockRequest->new(user => $root_user);
  my ($notif_status, $notif_response) = @{$notifications_api->get_all($root_request)};

  is($notif_status, 200, 'Notifications API call succeeded (HTTP 200)');
  ok(scalar(@{$notif_response->{notifications}}) > 0, 'Notifications API returned notifications');

  $DB->sqlDelete('notified', "notified_id=$notification->{notified_id}");
  $DB->sqlDelete('nodenote', "nodenote_nodeid=$test_writeup_id AND noter_user=$genericeditor->{user_id}");
};

# NOTE: getRenderedNotifications() HTML rendering is tested elsewhere
# This test suite focuses on the broadcast notification database pattern


# Cleanup
my $VARS = $APP->getVars($root);
if ($VARS->{settings}) {
  my $settings = decode_json($VARS->{settings});
  delete $settings->{notifications}->{$nodenote_notification->{node_id}} if $settings->{notifications};
  $VARS->{settings} = encode_json($settings);
  Everything::setVars($root, $VARS);
}

done_testing();
