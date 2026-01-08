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
use Everything::API::favorites;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::favorites->new();
ok($api, "Created favorites API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $target_user = $DB->getNode("normaluser2", "user");
ok($target_user, "Got target user for favorite tests");

my $another_user = $DB->getNode("normaluser3", "user");
ok($another_user, "Got another user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Get the favorite linktype
my $favorite_linktype = $DB->getNode('favorite', 'linktype');
ok($favorite_linktype, "Got favorite linktype");

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'get_all', "get_all route exists");
is($routes->{'/:id'}, 'get_single(:id)', "get_single route exists");
is($routes->{'/:id/action/favorite'}, 'favorite(:id)', "favorite route exists");
is($routes->{'/:id/action/unfavorite'}, 'unfavorite(:id)', "unfavorite route exists");

#############################################################################
# Test: Authorization - guest user blocked
#############################################################################

subtest 'Authorization: guest users blocked' => sub {
    plan tests => 4;

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user
    );

    # Test all endpoints return 401 for guests
    my $result = $api->get_all($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, "get_all returns 401 for guest");

    $result = $api->get_single($guest_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "get_single returns 401 for guest");

    $result = $api->favorite($guest_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "favorite returns 401 for guest");

    $result = $api->unfavorite($guest_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "unfavorite returns 401 for guest");
};

#############################################################################
# Test: Favorite workflow
#############################################################################

subtest 'Favorite workflow' => sub {
    plan tests => 12;

    my $user_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    # Clean up any existing favorite first
    $DB->sqlDelete('links',
        "from_node = " . $normal_user->{node_id} .
        " AND to_node = " . $target_user->{node_id} .
        " AND linktype = " . $favorite_linktype->{node_id}
    );

    # Test get_single - not favorited initially
    my $result = $api->get_single($user_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "get_single returns 200");
    is($result->[1]->{success}, 1, "get_single success");
    is($result->[1]->{is_favorited}, 0, "User is not favorited initially");

    # Test favorite action
    $result = $api->favorite($user_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "favorite returns 200");
    is($result->[1]->{success}, 1, "favorite success");
    is($result->[1]->{is_favorited}, 1, "User is now favorited");

    # Test get_single - should now be favorited
    $result = $api->get_single($user_request, $target_user->{node_id});
    is($result->[1]->{is_favorited}, 1, "get_single shows favorited");

    # Test double favorite (should still succeed)
    $result = $api->favorite($user_request, $target_user->{node_id});
    is($result->[1]->{success}, 1, "Double favorite still succeeds");
    is($result->[1]->{message}, 'Already favorited', "Returns already favorited message");

    # Test unfavorite action
    $result = $api->unfavorite($user_request, $target_user->{node_id});
    is($result->[0], $api->HTTP_OK, "unfavorite returns 200");
    is($result->[1]->{success}, 1, "unfavorite success");
    is($result->[1]->{is_favorited}, 0, "User is now unfavorited");
};

#############################################################################
# Test: Cannot favorite yourself
#############################################################################

subtest 'Cannot favorite yourself' => sub {
    plan tests => 2;

    my $user_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->favorite($user_request, $normal_user->{node_id});
    is($result->[1]->{success}, 0, "Cannot favorite yourself - fails");
    like($result->[1]->{error}, qr/yourself/i, "Error mentions yourself");
};

#############################################################################
# Test: Invalid user returns error
#############################################################################

subtest 'Invalid user returns error' => sub {
    plan tests => 2;

    my $user_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->favorite($user_request, 999999999);
    is($result->[1]->{success}, 0, "Invalid user fails");
    like($result->[1]->{error}, qr/not found/i, "Error mentions not found");
};

#############################################################################
# Test: get_all returns favorited users
#############################################################################

subtest 'get_all returns favorited users' => sub {
    plan tests => 4;

    my $user_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    # Clean slate
    $DB->sqlDelete('links',
        "from_node = " . $normal_user->{node_id} .
        " AND linktype = " . $favorite_linktype->{node_id}
    );

    # Add some favorites
    $api->favorite($user_request, $target_user->{node_id});
    $api->favorite($user_request, $another_user->{node_id});

    # Get all favorites
    my $result = $api->get_all($user_request);
    is($result->[0], $api->HTTP_OK, "get_all returns 200");
    is($result->[1]->{success}, 1, "get_all success");
    ok(ref($result->[1]->{favorites}) eq 'ARRAY', "favorites is array");
    is(scalar(@{$result->[1]->{favorites}}), 2, "Has 2 favorites");

    # Cleanup
    $DB->sqlDelete('links',
        "from_node = " . $normal_user->{node_id} .
        " AND linktype = " . $favorite_linktype->{node_id}
    );
};

done_testing();
