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
use Everything::API::bouncer;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::bouncer->new();
ok($api, "Created bouncer API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Check for chanop group
my $chanops_group = $DB->getNode('chanops', 'usergroup');
my $can_test_chanop = defined($chanops_group);

# Check if room type exists
my $room_type = $DB->getType('room');
my $can_test_rooms = defined($room_type);

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'move_users', "move_users route exists");

#############################################################################
# Test: move_users - guest user denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    request_method => 'POST'
);

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { usernames => ['normaluser1'], room_title => 'outside' };
    };
}

# Note: unauthorized_if_guest wrapper returns 401 UNAUTHORIZED with no body
my $result = $api->move_users($guest_request);
is($result->[0], $api->HTTP_UNAUTHORIZED, "Guest move_users returns 401");

#############################################################################
# Test: move_users - non-chanop denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'POST'
);

$result = $api->move_users($normal_request);
is($result->[0], $api->HTTP_OK, "Non-chanop returns HTTP 200");
is($result->[1]{success}, 0, "Non-chanop fails");
like($result->[1]{error}, qr/permission denied|chanop/i, "Error mentions permission/chanop");

#############################################################################
# Test: move_users - invalid JSON body
#############################################################################

# Temporarily make admin appear as chanop for testing
SKIP: {
    skip "Chanops group not available", 30 unless $can_test_chanop;

    # Add admin to chanops for testing
    my $was_chanop = $APP->isChanop($admin_user);
    unless ($was_chanop) {
        $DB->sqlInsert('nodegroup', {
            nodegroup_id => $chanops_group->{node_id},
            node_id => $admin_user->{node_id},
            orderby => 999,
            nodegroup_rank => 999
        });
    }

    my $chanop_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST'
    );

    # Test invalid JSON
    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub { return undef; };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Invalid JSON returns HTTP 200");
    is($result->[1]{success}, 0, "Invalid JSON fails");
    like($result->[1]{error}, qr/invalid json/i, "Error mentions invalid JSON");

    #############################################################################
    # Test: move_users - no usernames provided
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { room_title => 'outside' };  # No usernames
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "No usernames returns HTTP 200");
    is($result->[1]{success}, 0, "No usernames fails");
    like($result->[1]{error}, qr/no usernames/i, "Error mentions no usernames");

    #############################################################################
    # Test: move_users - empty usernames array
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => [], room_title => 'outside' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Empty usernames returns HTTP 200");
    is($result->[1]{success}, 0, "Empty usernames fails");
    like($result->[1]{error}, qr/no usernames/i, "Error mentions no usernames");

    #############################################################################
    # Test: move_users - no room specified
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['normaluser1'] };  # No room
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "No room returns HTTP 200");
    is($result->[1]{success}, 0, "No room fails");
    like($result->[1]{error}, qr/no room/i, "Error mentions no room");

    #############################################################################
    # Test: move_users - empty room specified
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['normaluser1'], room_title => '   ' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Empty room returns HTTP 200");
    is($result->[1]{success}, 0, "Empty room fails");
    like($result->[1]{error}, qr/no room/i, "Error mentions no room");

    #############################################################################
    # Test: move_users - non-existent room
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['normaluser1'], room_title => 'NonExistentRoom12345' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Non-existent room returns HTTP 200");
    is($result->[1]{success}, 0, "Non-existent room fails");
    like($result->[1]{error}, qr/does not exist/i, "Error mentions room doesn't exist");

    #############################################################################
    # Test: move_users - move to outside (special case)
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['normaluser1', 'normaluser2'], room_title => 'outside' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Move to outside returns HTTP 200");
    is($result->[1]{success}, 1, "Move to outside succeeds");
    is($result->[1]{room_title}, 'outside', "Room title is 'outside'");
    ok(ref($result->[1]{moved}) eq 'ARRAY', "Moved is an array");
    ok(ref($result->[1]{not_found}) eq 'ARRAY', "Not found is an array");
    ok($result->[1]{message}, "Message present");

    #############################################################################
    # Test: move_users - non-existent users
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['nonexistentuser123', 'alsobaduser456'], room_title => 'outside' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Non-existent users returns HTTP 200");
    is($result->[1]{success}, 1, "Operation succeeds (but no users moved)");
    is(scalar(@{$result->[1]{moved}}), 0, "No users moved");
    is(scalar(@{$result->[1]{not_found}}), 2, "Two users not found");

    #############################################################################
    # Test: move_users - mixed existing and non-existing users
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::JSON_POSTDATA = sub {
            return { usernames => ['normaluser1', 'nonexistentuser999'], room_title => 'outside' };
        };
    }

    $result = $api->move_users($chanop_request);
    is($result->[0], $api->HTTP_OK, "Mixed users returns HTTP 200");
    is($result->[1]{success}, 1, "Mixed users succeeds");
    ok(scalar(@{$result->[1]{moved}}) >= 1, "At least one user moved");
    ok(scalar(@{$result->[1]{not_found}}) >= 1, "At least one user not found");

    # Cleanup: Remove admin from chanops if we added them
    unless ($was_chanop) {
        $DB->sqlDelete('nodegroup',
            "nodegroup_id = $chanops_group->{node_id} AND node_id = $admin_user->{node_id}");
    }
}

done_testing();

=head1 NAME

t/076_bouncer_api.t - Tests for Everything::API::bouncer

=head1 DESCRIPTION

Tests for the bouncer API covering:
- Guest user denied
- Non-chanop permission check
- Invalid JSON body
- Missing usernames
- Empty usernames array
- Missing room
- Non-existent room
- Move to outside (special case)
- Non-existent users handling
- Mixed existing/non-existing users

=head1 AUTHOR

Everything2 Development Team

=cut
