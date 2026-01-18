#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::preferences;
use JSON;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test: Notification Preferences Isolation
#
# This test verifies that saving notification preferences does NOT erase
# other user settings. This was a critical bug where setVars was called
# with only the 'settings' key, causing all other vars to be deleted.
#
# Bug: set_notification_preferences was calling:
#   Everything::setVars($user_node, { settings => $settings_json });
#
# This passed only ONE key to setVars, which then deleted all other vars
# because setVars line 252:
#   map { delete $currentVars{$_} if !defined $$varsref{$_}; } keys %currentVars;
#
# Fix: Pass ALL vars, not just settings:
#   $VARS->{settings} = JSON::encode_json($settings);
#   Everything::setVars($user_node, $VARS);
#############################################################################

# Get test user
my $test_user = $DB->getNode("e2e_user", "user");
ok($test_user, "Got test user (e2e_user)");

# Get a valid notification type
my $notification_type = $DB->getType('notification');
ok($notification_type, "Got notification type");

my $sample_notification = $DB->sqlSelectHashref('node_id, title', 'node',
    "type_nodetype = $notification_type->{node_id} LIMIT 1");
ok($sample_notification, "Got sample notification type for testing");

# Create API instance
my $api = Everything::API::preferences->new();
ok($api, "Created preferences API instance");

#############################################################################
# Helper: Create a real request with actual VARS from database
#############################################################################

package RealUserRequest;
use JSON;

sub new {
    my ($class, %args) = @_;
    # Create and cache the RealUser object - IMPORTANT: must return the
    # SAME user object on each call to user() so that modifications to
    # VARS are preserved between calls within the same API method.
    my $user = RealUser->new(%args);
    return bless {
        %args,
        _cached_user => $user,
    }, $class;
}

sub user {
    my $self = shift;
    return $self->{_cached_user};
}

sub JSON_POSTDATA { return shift->{postdata}; }
sub is_guest { return 0; }

package RealUser;

sub new {
    my ($class, %args) = @_;
    # Cache the VARS hashref so multiple calls return the same reference
    # This is required because set_preferences modifies VARS then calls set_vars(VARS)
    my $node = $Everything::DB->getNodeById($args{node_id}, 'force');
    my $vars = Everything::getVars($node);
    return bless {
        %args,
        _cached_vars => $vars,
        _cached_node => $node,
    }, $class;
}

sub node_id { return shift->{node_id}; }
sub title { return shift->{title}; }
sub is_guest { return 0; }

sub NODEDATA {
    my $self = shift;
    return $self->{_cached_node};
}

sub VARS {
    my $self = shift;
    return $self->{_cached_vars};
}

sub set_vars {
    my ($self, $vars) = @_;
    # Use 'force' to bypass node cache and get fresh node for setVars
    my $node = $Everything::DB->getNodeById($self->{node_id}, 'force');
    Everything::setVars($node, $vars);
    return 1;
}

package main;

#############################################################################
# Test 1: Setting a preference before notification changes
#############################################################################

subtest 'Saving preferences preserves existing vars' => sub {
    plan tests => 8;

    my $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    ok($user_node, "Got user node from database");

    # Get current VARS
    my $vars_before = Everything::getVars($user_node);

    # Set a distinctive preference value using the regular preferences API
    my $request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => { votesafety => 1 }
    );

    my $result = $api->set_preferences($request);
    is($result->[0], $api->HTTP_OK, "Set preference returns 200 OK");

    # Verify preference was set
    $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    my $vars_after_pref = Everything::getVars($user_node);
    is($vars_after_pref->{votesafety}, 1, "votesafety preference was set to 1");

    # Now save notification preferences
    my $notif_request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => {
            notifications => { $sample_notification->{node_id} => 1 }
        }
    );

    $result = $api->set_notification_preferences($notif_request);
    is($result->[0], $api->HTTP_OK, "Set notification preferences returns 200 OK");
    is($result->[1]->{success}, 1, "Notification preferences saved successfully");

    # CRITICAL TEST: Verify that votesafety is STILL set to 1
    $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    my $vars_after_notif = Everything::getVars($user_node);
    is($vars_after_notif->{votesafety}, 1,
        "CRITICAL: votesafety preference is PRESERVED after saving notifications");

    # Verify notification was actually saved
    my $settings = eval { JSON::decode_json($vars_after_notif->{settings} || '{}') };
    ok($settings, "Settings JSON is valid");
    is($settings->{notifications}{$sample_notification->{node_id}}, 1,
        "Notification preference was saved correctly");
};

#############################################################################
# Test 2: Multiple preferences preserved across notification changes
#############################################################################

subtest 'Multiple preferences preserved after notification save' => sub {
    plan tests => 7;

    # Set multiple different preferences
    my $request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => {
            votesafety => 1,
            coolsafety => 1,
            hidenodeshells => 1
        }
    );

    my $result = $api->set_preferences($request);
    is($result->[0], $api->HTTP_OK, "Set multiple preferences returns 200 OK");

    # Now save different notification preferences
    my $notif_request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => {
            notifications => {}  # Empty - turning off all notifications
        }
    );

    $result = $api->set_notification_preferences($notif_request);
    is($result->[0], $api->HTTP_OK, "Set empty notification preferences returns 200 OK");

    # Verify ALL preferences are still there
    my $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    my $vars = Everything::getVars($user_node);

    is($vars->{votesafety}, 1, "votesafety preserved");
    is($vars->{coolsafety}, 1, "coolsafety preserved");
    is($vars->{hidenodeshells}, 1, "hidenodeshells preserved");

    # Verify settings JSON still valid
    my $settings = eval { JSON::decode_json($vars->{settings} || '{}') };
    ok($settings, "Settings JSON is still valid");
    ok(ref($settings->{notifications}) eq 'HASH', "Notifications is empty hash as expected");
};

#############################################################################
# Test 3: Repeated notification saves don't accumulate data loss
#############################################################################

subtest 'Repeated notification saves preserve all vars' => sub {
    plan tests => 5;  # 1 set_preferences + 3 notification saves + 1 final check

    # Set a preference
    my $request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => { noSoftLinks => 1 }
    );

    my $result = $api->set_preferences($request);
    is($result->[0], $api->HTTP_OK, "Set noSoftLinks preference");

    # Save notifications multiple times
    for my $i (1..3) {
        my $notif_request = RealUserRequest->new(
            node_id => $test_user->{node_id},
            title => $test_user->{title},
            postdata => {
                notifications => { $sample_notification->{node_id} => 1 }
            }
        );

        $result = $api->set_notification_preferences($notif_request);
        is($result->[0], $api->HTTP_OK, "Notification save $i returns 200 OK");
    }

    # After 3 saves, noSoftLinks should still be there
    my $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    my $vars = Everything::getVars($user_node);
    is($vars->{noSoftLinks}, 1,
        "noSoftLinks preserved after 3 notification saves");
};

#############################################################################
# Test 4: String preferences (like collapsedNodelets) preserved
#############################################################################

subtest 'String preferences preserved after notification save' => sub {
    plan tests => 4;

    # Set a string preference
    my $collapsed_value = "epicenter!readthis!";
    my $request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => { collapsedNodelets => $collapsed_value }
    );

    my $result = $api->set_preferences($request);
    is($result->[0], $api->HTTP_OK, "Set collapsedNodelets preference");

    # Save notification preferences
    my $notif_request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => {
            notifications => { $sample_notification->{node_id} => 1 }
        }
    );

    $result = $api->set_notification_preferences($notif_request);
    is($result->[0], $api->HTTP_OK, "Notification save returns 200 OK");

    # Verify string preference preserved
    my $user_node = $DB->getNodeById($test_user->{node_id}, 'force');
    my $vars = Everything::getVars($user_node);
    is($vars->{collapsedNodelets}, $collapsed_value,
        "String preference (collapsedNodelets) preserved");

    # Verify it's exactly the same (no corruption)
    ok($vars->{collapsedNodelets} eq $collapsed_value,
        "String value not corrupted during notification save");
};

#############################################################################
# Cleanup: Reset test user preferences to defaults
#############################################################################

subtest 'Cleanup test user' => sub {
    plan tests => 1;

    # Reset all the test preferences we set
    my $request = RealUserRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        postdata => {
            votesafety => 0,
            coolsafety => 0,
            hidenodeshells => 0,
            noSoftLinks => 0,
            collapsedNodelets => ''
        }
    );

    my $result = $api->set_preferences($request);
    is($result->[0], $api->HTTP_OK, "Cleanup: reset preferences to defaults");
};

done_testing();
