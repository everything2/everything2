#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::userinteractions;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::userinteractions->new();
ok($api, "Created userinteractions API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $target_user = $DB->getNode("normaluser2", "user");
ok($target_user, "Got target user for blocking tests");

my $another_user = $DB->getNode("normaluser3", "user");
ok($another_user, "Got another user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'get_all', "get_all route exists");
is($routes->{'create'}, 'create', "create route exists");
is($routes->{'/:id'}, 'get_single(:id)', "get_single route exists");
is($routes->{'/:id/action/update'}, 'update(:id)', "update route exists");
is($routes->{'/:id/action/delete'}, 'delete(:id)', "delete route exists");

#############################################################################
# Test: Authorization - guest user blocked
#############################################################################

subtest 'Authorization: guest users blocked' => sub {
    plan tests => 5;

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user
    );

    # Test all endpoints return 401 for guests
    my $result = $api->get_all($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "get_all returns 401 for guest");

    $result = $api->create($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "create returns 401 for guest");

    $result = $api->get_single($guest_request, 123);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "get_single returns 401 for guest");

    $result = $api->update($guest_request, 123);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "update returns 401 for guest");

    $result = $api->delete($guest_request, 123);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "delete returns 401 for guest");
};

#############################################################################
# Test: get_all - initially empty
#############################################################################

subtest 'get_all: initially empty' => sub {
    plan tests => 3;

    # Clean up any existing blocks
    cleanup_blocks($normal_user, $target_user);
    cleanup_blocks($normal_user, $another_user);

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_all($request);
    is($result->[0], $api->HTTP_OK, "get_all returns HTTP 200");
    ok(exists $result->[1]{blocked_users}, "Response has blocked_users array");
    is(ref($result->[1]{blocked_users}), 'ARRAY', "blocked_users is an array");
};

#############################################################################
# Test: create - block user with hide_writeups
#############################################################################

subtest 'create: block user with hide_writeups' => sub {
    plan tests => 6;

    cleanup_blocks($normal_user, $target_user);

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            username => $target_user->{title},
            hide_writeups => 1,
            block_messages => 0
        }
    );

    my $result = $api->create($request);
    is($result->[0], $api->HTTP_OK, "create returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{node_id}, $target_user->{node_id}, "Correct node_id returned");
    is($result->[1]{title}, $target_user->{title}, "Correct title returned");
    is($result->[1]{hide_writeups}, 1, "hide_writeups is set in response");
    is($result->[1]{block_messages}, 0, "block_messages is not set in response");

    # Note: MockUser's set_vars only updates in-memory, VARS persistence not tested here
    # The API correctly calls set_vars - that's what we're testing
};

#############################################################################
# Test: create - block user with block_messages
#############################################################################

subtest 'create: block user with block_messages' => sub {
    plan tests => 6;

    cleanup_blocks($normal_user, $another_user);

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            node_id => $another_user->{node_id},
            hide_writeups => 0,
            block_messages => 1
        }
    );

    my $result = $api->create($request);
    is($result->[0], $api->HTTP_OK, "create returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{hide_writeups}, 0, "hide_writeups is not set");
    is($result->[1]{block_messages}, 1, "block_messages is set");

    # Verify in database
    my $exists = $DB->sqlSelect('*', 'messageignore',
        "messageignore_id=" . $normal_user->{node_id} . " AND ignore_node=" . $another_user->{node_id});
    ok($exists, "Message ignore record exists in database");

    # Clean up
    cleanup_blocks($normal_user, $another_user);
    $exists = $DB->sqlSelect('*', 'messageignore',
        "messageignore_id=" . $normal_user->{node_id} . " AND ignore_node=" . $another_user->{node_id});
    ok(!$exists, "Message ignore record removed after cleanup");
};

#############################################################################
# Test: create - user not found
#############################################################################

subtest 'create: user not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            username => 'nonexistent_user_xyz123',
            hide_writeups => 1
        }
    );

    my $result = $api->create($request);
    is($result->[0], $api->HTTP_OK, "create returns HTTP 200");
    is($result->[1]{success}, 0, "Success flag is false for nonexistent user");
};

#############################################################################
# Test: get_single - existing block
#############################################################################

subtest 'get_single: existing block (message block)' => sub {
    plan tests => 5;

    cleanup_blocks($normal_user, $target_user);

    # First create a block with block_messages (persisted to DB)
    my $create_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            node_id => $target_user->{node_id},
            hide_writeups => 0,
            block_messages => 1
        }
    );
    $api->create($create_request);

    # Now query it - block_messages persists to DB, so it should show
    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_single($request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "get_single returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{node_id}, $target_user->{node_id}, "Correct node_id");
    is($result->[1]{title}, $target_user->{title}, "Correct title");
    is($result->[1]{block_messages}, 1, "block_messages is set (persisted to DB)");
};

#############################################################################
# Test: get_single - not blocked
#############################################################################

subtest 'get_single: user not blocked' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    # Query a user that is not blocked
    my $result = $api->get_single($request, $another_user->{node_id});
    is($result->[0], $api->HTTP_OK, "get_single returns HTTP 200");
    is($result->[1]{success}, 0, "Success is false for non-blocked user");
};

#############################################################################
# Test: get_all - with blocked users
#############################################################################

subtest 'get_all: returns blocked users (message blocks)' => sub {
    plan tests => 4;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_all($request);
    is($result->[0], $api->HTTP_OK, "get_all returns HTTP 200");
    ok(scalar(@{$result->[1]{blocked_users}}) >= 1, "At least one blocked user returned");

    # Find target_user in the list - should appear due to message block (DB)
    my ($found) = grep { $_->{node_id} == $target_user->{node_id} } @{$result->[1]{blocked_users}};
    ok($found, "Target user found in blocked list");
    is($found->{block_messages}, 1, "block_messages flag is correct") if $found;
};

#############################################################################
# Test: update - change block settings
#############################################################################

subtest 'update: change block settings' => sub {
    plan tests => 5;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            hide_writeups => 0,
            block_messages => 0  # Remove message block
        }
    );

    my $result = $api->update($request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "update returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{hide_writeups}, 0, "hide_writeups is 0 in response");
    is($result->[1]{block_messages}, 0, "block_messages is 0 in response");

    # Verify the message block was removed from DB
    my $exists = $DB->sqlSelect('*', 'messageignore',
        "messageignore_id=" . $normal_user->{node_id} . " AND ignore_node=" . $target_user->{node_id});
    ok(!$exists, "Message ignore record removed from database");
};

#############################################################################
# Test: delete - remove block
#############################################################################

subtest 'delete: remove block' => sub {
    plan tests => 5;

    # First create a message block
    my $create_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            node_id => $target_user->{node_id},
            hide_writeups => 0,
            block_messages => 1
        }
    );
    $api->create($create_request);

    # Verify it was created
    my $exists = $DB->sqlSelect('*', 'messageignore',
        "messageignore_id=" . $normal_user->{node_id} . " AND ignore_node=" . $target_user->{node_id});
    ok($exists, "Message ignore record exists before delete");

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->delete($request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "delete returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");

    # Verify removal via get_single
    my $verify_result = $api->get_single($request, $target_user->{node_id});
    is($verify_result->[1]{success}, 0, "User no longer appears as blocked");

    # Verify database cleanup
    $exists = $DB->sqlSelect('*', 'messageignore',
        "messageignore_id=" . $normal_user->{node_id} . " AND ignore_node=" . $target_user->{node_id});
    ok(!$exists, "Message ignore record removed from database");
};

#############################################################################
# Test: create - both hide_writeups and block_messages
#############################################################################

subtest 'create: block with both options' => sub {
    plan tests => 5;

    cleanup_blocks($normal_user, $target_user);

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            username => $target_user->{title},
            hide_writeups => 1,
            block_messages => 1
        }
    );

    my $result = $api->create($request);
    is($result->[0], $api->HTTP_OK, "create returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{hide_writeups}, 1, "hide_writeups is set");
    is($result->[1]{block_messages}, 1, "block_messages is set");

    # Clean up
    $api->delete($request, $target_user->{node_id});
    my $verify = $api->get_single($request, $target_user->{node_id});
    is($verify->[1]{success}, 0, "Block removed after cleanup");
};

#############################################################################
# Cleanup helper
#############################################################################

sub cleanup_blocks {
    my ($blocker, $blocked) = @_;

    # Remove from unfavoriteusers VARS
    my $VARS = $APP->getVars($blocker);
    if ($VARS->{unfavoriteusers}) {
        my @current = split(/,/, $VARS->{unfavoriteusers});
        my @filtered = grep { $_ ne $blocked->{node_id} } @current;
        $VARS->{unfavoriteusers} = join(',', @filtered);
        # Save VARS back
        my $vars_string = join('&', map { "$_=$VARS->{$_}" } keys %$VARS);
        $DB->sqlUpdate('setting', { vars => $vars_string },
            "setting_id = " . $blocker->{node_id});
    }

    # Remove from messageignore table
    $DB->sqlDelete('messageignore',
        "messageignore_id=" . $blocker->{node_id} . " AND ignore_node=" . $blocked->{node_id});
}

#############################################################################
# Final cleanup
#############################################################################

cleanup_blocks($normal_user, $target_user);
cleanup_blocks($normal_user, $another_user);

done_testing();

=head1 NAME

t/080_userinteractions_api.t - Tests for Everything::API::userinteractions

=head1 DESCRIPTION

Tests for the unified user interactions API covering:
- Authorization checks (guest users blocked)
- get_all - list blocked users
- create - block a user (hide_writeups and/or block_messages)
- get_single - get block status for specific user
- update - modify block settings
- delete - remove a block

=head1 AUTHOR

Everything2 Development Team

=cut
