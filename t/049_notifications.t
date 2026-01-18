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

#############################################################################
# Cross-user isolation tests
# These tests verify that notifications are properly isolated between users
#############################################################################

# Get additional test users for isolation testing
my $genericdev = $DB->getNode('genericdev', 'user');
my $e2e_user = $DB->getNode('e2e_user', 'user');

# Get voting notification for direct notification tests
my $voting_notification = $DB->getNode('voting', 'notification');

subtest 'Direct notification isolation - User A cannot see User B notifications' => sub {
  SKIP: {
    skip "Need voting notification and test users", 1 unless $voting_notification && $genericdev && $e2e_user && $test_writeup_id;

    # Create a direct notification for genericdev (User A)
    # Use real writeup ID so validity check passes
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $voting_notification->{node_id},
      user_id => $genericdev->{user_id},  # Direct to genericdev
      args => encode_json({ node_id => $test_writeup_id, weight => 1, amount => 1 }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created direct notification for genericdev (notified_id: $inserted_id)");

    # Verify genericdev CAN see this notification
    my $genericdev_VARS = $APP->getVars($genericdev);
    # Subscribe genericdev to voting notifications
    my $gd_settings = $genericdev_VARS->{settings} ? decode_json($genericdev_VARS->{settings}) : {};
    $gd_settings->{notifications} ||= {};
    $gd_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $genericdev_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $genericdev_VARS);

    my $genericdev_notifications = $APP->getRenderedNotifications($genericdev, $APP->getVars($genericdev));
    my $gd_has_notification = grep { $_->{notified_id} == $inserted_id } @$genericdev_notifications;
    ok($gd_has_notification, "genericdev CAN see their own direct notification");

    # Verify e2e_user CANNOT see genericdev's notification
    my $e2e_VARS = $APP->getVars($e2e_user);
    # Subscribe e2e_user to voting notifications too
    my $e2e_settings = $e2e_VARS->{settings} ? decode_json($e2e_VARS->{settings}) : {};
    $e2e_settings->{notifications} ||= {};
    $e2e_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $e2e_VARS->{settings} = encode_json($e2e_settings);
    Everything::setVars($e2e_user, $e2e_VARS);

    my $e2e_notifications = $APP->getRenderedNotifications($e2e_user, $APP->getVars($e2e_user));
    my $e2e_has_notification = grep { $_->{notified_id} == $inserted_id } @$e2e_notifications;
    ok(!$e2e_has_notification, "e2e_user CANNOT see genericdev's direct notification");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");

    # Restore original settings
    delete $gd_settings->{notifications}->{$voting_notification->{node_id}};
    $genericdev_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $genericdev_VARS);

    delete $e2e_settings->{notifications}->{$voting_notification->{node_id}};
    $e2e_VARS->{settings} = encode_json($e2e_settings);
    Everything::setVars($e2e_user, $e2e_VARS);
  }
};

subtest 'Broadcast notification - only subscribers see it' => sub {
  SKIP: {
    skip "Need nodenote notification and test users", 1 unless $nodenote_notification && $root && $genericdev && $test_writeup_id;

    # Create a real nodenote first so validity check passes
    my $nodenote_insert_id = $DB->sqlInsert('nodenote', {
      nodenote_nodeid => $test_writeup_id,
      noter_user => $root->{user_id},
      -timestamp => 'NOW()',
      notetext => 'Test note for broadcast test'
    });
    my $real_nodenote_id = $DB->sqlSelect('LAST_INSERT_ID()');

    # Create a broadcast notification (user_id = notification_id)
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $nodenote_notification->{node_id},
      user_id => $nodenote_notification->{node_id},  # Broadcast pattern
      args => encode_json({ node_id => $test_writeup_id, nodenote_id => $real_nodenote_id }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created broadcast notification (notified_id: $inserted_id)");

    # Subscribe root to nodenote (root is an editor, so can see nodenote)
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$nodenote_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    # Root should see the broadcast notification
    my $root_notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $root_has_notification = grep { $_->{notified_id} == $inserted_id } @$root_notifications;
    ok($root_has_notification, "Subscribed user (root) CAN see broadcast notification");

    # Unsubscribe root from nodenote
    delete $root_settings->{notifications}->{$nodenote_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    # Root should NOT see the broadcast notification when unsubscribed
    my $root_notifications_after = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $root_has_notification_after = grep { $_->{notified_id} == $inserted_id } @$root_notifications_after;
    ok(!$root_has_notification_after, "Unsubscribed user (root) CANNOT see broadcast notification");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    $DB->sqlDelete('nodenote', "nodenote_id = $real_nodenote_id") if $real_nodenote_id;
  }
};

subtest 'Broadcast notification - non-editor cannot see editor-only notifications' => sub {
  SKIP: {
    skip "Need nodenote notification and e2e_user", 1 unless $nodenote_notification && $e2e_user && $test_writeup_id;

    # Create a real nodenote first so validity check passes
    my $nodenote_insert_id = $DB->sqlInsert('nodenote', {
      nodenote_nodeid => $test_writeup_id,
      noter_user => $root->{user_id},
      -timestamp => 'NOW()',
      notetext => 'Editor test note for permission test'
    });
    my $real_nodenote_id = $DB->sqlSelect('LAST_INSERT_ID()');

    # Create broadcast notification with real node and nodenote IDs
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $nodenote_notification->{node_id},
      user_id => $nodenote_notification->{node_id},  # Broadcast pattern
      args => encode_json({ node_id => $test_writeup_id, nodenote_id => $real_nodenote_id }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created editor-only broadcast notification (notified_id: $inserted_id)");

    # Subscribe e2e_user to nodenote (e2e_user is NOT an editor)
    my $e2e_VARS = $APP->getVars($e2e_user);
    my $e2e_settings = $e2e_VARS->{settings} ? decode_json($e2e_VARS->{settings}) : {};
    $e2e_settings->{notifications} ||= {};
    $e2e_settings->{notifications}->{$nodenote_notification->{node_id}} = 1;
    $e2e_VARS->{settings} = encode_json($e2e_settings);
    Everything::setVars($e2e_user, $e2e_VARS);

    # e2e_user should NOT see the notification (not an editor)
    my $e2e_notifications = $APP->getRenderedNotifications($e2e_user, $APP->getVars($e2e_user));
    my $e2e_has_notification = grep { $_->{notified_id} == $inserted_id } @$e2e_notifications;
    ok(!$e2e_has_notification, "Non-editor CANNOT see editor-only broadcast notification even when subscribed");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    $DB->sqlDelete('nodenote', "nodenote_id = $real_nodenote_id") if $real_nodenote_id;
    delete $e2e_settings->{notifications}->{$nodenote_notification->{node_id}};
    $e2e_VARS->{settings} = encode_json($e2e_settings);
    Everything::setVars($e2e_user, $e2e_VARS);
  }
};

subtest 'Multiple users with same subscription - each sees broadcast independently' => sub {
  SKIP: {
    skip "Need voting notification and multiple test users", 1 unless $voting_notification && $root && $genericdev;

    # Get e2poll notification for this test (it's a broadcast anyone can subscribe to)
    my $e2poll_notification = $DB->getNode('e2poll', 'notification');
    skip "Need e2poll notification", 1 unless $e2poll_notification;

    # Find a real poll node for the validity check to pass
    my $e2poll_type = $DB->getNode('e2poll', 'nodetype');
    my $real_poll_id = $DB->sqlSelect('node_id', 'node', "type_nodetype = $e2poll_type->{node_id}", 'LIMIT 1');
    skip "Need a real poll node", 1 unless $real_poll_id;

    # Create a broadcast e2poll notification with real poll ID
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $e2poll_notification->{node_id},
      user_id => $e2poll_notification->{node_id},  # Broadcast pattern
      args => encode_json({ node_id => $real_poll_id }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created e2poll broadcast notification (notified_id: $inserted_id)");

    # Subscribe both root and genericdev to e2poll
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$e2poll_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    my $gd_VARS = $APP->getVars($genericdev);
    my $gd_settings = $gd_VARS->{settings} ? decode_json($gd_VARS->{settings}) : {};
    $gd_settings->{notifications} ||= {};
    $gd_settings->{notifications}->{$e2poll_notification->{node_id}} = 1;
    $gd_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $gd_VARS);

    # Both users should see the same notification
    my $root_notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $root_has_notification = grep { $_->{notified_id} == $inserted_id } @$root_notifications;
    ok($root_has_notification, "Root CAN see shared broadcast notification");

    my $gd_notifications = $APP->getRenderedNotifications($genericdev, $APP->getVars($genericdev));
    my $gd_has_notification = grep { $_->{notified_id} == $inserted_id } @$gd_notifications;
    ok($gd_has_notification, "genericdev CAN see same shared broadcast notification");

    # When root dismisses it, genericdev should still see it
    # Create a reference record for root to mark as dismissed
    $DB->sqlInsert('notified', {
      notification_id => 1,  # Dummy
      user_id => $root->{user_id},
      reference_notified_id => $inserted_id,
      is_seen => 1,
      -notified_time => 'NOW()',
      args => '{}'
    });
    my $reference_id = $DB->sqlSelect('LAST_INSERT_ID()');

    # Root should NOT see it now (dismissed)
    my $root_notifications_after = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $root_has_notification_after = grep { $_->{notified_id} == $inserted_id } @$root_notifications_after;
    ok(!$root_has_notification_after, "Root CANNOT see broadcast after dismissing");

    # genericdev should STILL see it (didn't dismiss)
    my $gd_notifications_after = $APP->getRenderedNotifications($genericdev, $APP->getVars($genericdev));
    my $gd_has_notification_after = grep { $_->{notified_id} == $inserted_id } @$gd_notifications_after;
    ok($gd_has_notification_after, "genericdev CAN still see broadcast (didn't dismiss)");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    $DB->sqlDelete('notified', "notified_id = $reference_id") if $reference_id;

    delete $root_settings->{notifications}->{$e2poll_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    delete $gd_settings->{notifications}->{$e2poll_notification->{node_id}};
    $gd_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $gd_VARS);
  }
};

subtest 'Direct notification - dismiss only affects owner' => sub {
  SKIP: {
    skip "Need voting notification and test users", 1 unless $voting_notification && $root && $genericdev;

    # Create direct notifications for BOTH users about the same real node
    # (testing user isolation, not node isolation)
    my $root_notified_id = $DB->sqlInsert('notified', {
      notification_id => $voting_notification->{node_id},
      user_id => $root->{user_id},  # Direct to root
      args => encode_json({ node_id => $test_writeup_id, weight => 1, amount => 1 }),
      -notified_time => 'NOW()',
      is_seen => 0
    });
    my $root_inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');

    my $gd_notified_id = $DB->sqlInsert('notified', {
      notification_id => $voting_notification->{node_id},
      user_id => $genericdev->{user_id},  # Direct to genericdev
      args => encode_json({ node_id => $test_writeup_id, weight => -1, amount => 1 }),
      -notified_time => 'NOW()',
      is_seen => 0
    });
    my $gd_inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');

    ok($root_inserted_id && $gd_inserted_id, "Created two separate direct notifications");

    # Subscribe both to voting
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    my $gd_VARS = $APP->getVars($genericdev);
    my $gd_settings = $gd_VARS->{settings} ? decode_json($gd_VARS->{settings}) : {};
    $gd_settings->{notifications} ||= {};
    $gd_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $gd_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $gd_VARS);

    # Root should see ONLY their notification
    my $root_notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $root_sees_own = grep { $_->{notified_id} == $root_inserted_id } @$root_notifications;
    my $root_sees_gd = grep { $_->{notified_id} == $gd_inserted_id } @$root_notifications;
    ok($root_sees_own, "Root sees their own direct notification");
    ok(!$root_sees_gd, "Root does NOT see genericdev's direct notification");

    # genericdev should see ONLY their notification
    my $gd_notifications = $APP->getRenderedNotifications($genericdev, $APP->getVars($genericdev));
    my $gd_sees_own = grep { $_->{notified_id} == $gd_inserted_id } @$gd_notifications;
    my $gd_sees_root = grep { $_->{notified_id} == $root_inserted_id } @$gd_notifications;
    ok($gd_sees_own, "genericdev sees their own direct notification");
    ok(!$gd_sees_root, "genericdev does NOT see root's direct notification");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $root_inserted_id");
    $DB->sqlDelete('notified', "notified_id = $gd_inserted_id");

    delete $root_settings->{notifications}->{$voting_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    delete $gd_settings->{notifications}->{$voting_notification->{node_id}};
    $gd_VARS->{settings} = encode_json($gd_settings);
    Everything::setVars($genericdev, $gd_VARS);
  }
};

#############################################################################
# Validity check tests (is_valid)
# These tests verify that notifications are filtered when content is deleted
#############################################################################

subtest 'Validity check - voting notification for deleted node is filtered' => sub {
  SKIP: {
    skip "Need voting notification and test users", 1 unless $voting_notification && $root;

    # Create a direct voting notification pointing to a non-existent node
    my $fake_node_id = 99999999;  # This node doesn't exist
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $voting_notification->{node_id},
      user_id => $root->{user_id},
      args => encode_json({ node_id => $fake_node_id, weight => 1, amount => 1 }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created voting notification for non-existent node (notified_id: $inserted_id)");

    # Subscribe root to voting notifications
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    # Get notifications - the invalid one should be filtered out
    my $notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $has_invalid = grep { $_->{notified_id} == $inserted_id } @$notifications;
    ok(!$has_invalid, "Voting notification for deleted node is NOT shown");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    delete $root_settings->{notifications}->{$voting_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);
  }
};

subtest 'Validity check - nodenote notification for deleted note is filtered' => sub {
  SKIP: {
    skip "Need nodenote notification, root, and a writeup", 1 unless $nodenote_notification && $root && $test_writeup_id;

    # Create a nodenote notification for a note that doesn't exist
    my $fake_nodenote_id = 88888888;  # This nodenote doesn't exist
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $nodenote_notification->{node_id},
      user_id => $nodenote_notification->{node_id},  # Broadcast pattern
      args => encode_json({ node_id => $test_writeup_id, nodenote_id => $fake_nodenote_id }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created nodenote notification for non-existent note (notified_id: $inserted_id)");

    # Subscribe root to nodenote notifications (root is an editor)
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$nodenote_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    # Get notifications - the invalid one should be filtered out
    my $notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $has_invalid = grep { $_->{notified_id} == $inserted_id } @$notifications;
    ok(!$has_invalid, "Nodenote notification for deleted note is NOT shown");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    delete $root_settings->{notifications}->{$nodenote_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);
  }
};

subtest 'Validity check - valid notification IS shown' => sub {
  SKIP: {
    skip "Need voting notification and test users", 1 unless $voting_notification && $root && $test_writeup_id;

    # Create a voting notification for a REAL node
    my $notified_id = $DB->sqlInsert('notified', {
      notification_id => $voting_notification->{node_id},
      user_id => $root->{user_id},
      args => encode_json({ node_id => $test_writeup_id, weight => 1, amount => 1 }),
      -notified_time => 'NOW()',
      is_seen => 0
    });

    my $inserted_id = $DB->sqlSelect('LAST_INSERT_ID()');
    ok($inserted_id, "Created voting notification for existing node (notified_id: $inserted_id)");

    # Subscribe root to voting notifications
    my $root_VARS = $APP->getVars($root);
    my $root_settings = $root_VARS->{settings} ? decode_json($root_VARS->{settings}) : {};
    $root_settings->{notifications} ||= {};
    $root_settings->{notifications}->{$voting_notification->{node_id}} = 1;
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);

    # Get notifications - the valid one SHOULD be shown
    my $notifications = $APP->getRenderedNotifications($root, $APP->getVars($root));
    my $has_valid = grep { $_->{notified_id} == $inserted_id } @$notifications;
    ok($has_valid, "Voting notification for existing node IS shown");

    # Cleanup
    $DB->sqlDelete('notified', "notified_id = $inserted_id");
    delete $root_settings->{notifications}->{$voting_notification->{node_id}};
    $root_VARS->{settings} = encode_json($root_settings);
    Everything::setVars($root, $root_VARS);
  }
};

# Cleanup
my $VARS = $APP->getVars($root);
if ($VARS->{settings}) {
  my $settings = decode_json($VARS->{settings});
  delete $settings->{notifications}->{$nodenote_notification->{node_id}} if $settings->{notifications};
  $VARS->{settings} = encode_json($settings);
  Everything::setVars($root, $VARS);
}

done_testing();
