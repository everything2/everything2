#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::user;
use MockRequest;
use MockUser;

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
# Test User API functionality
#
# These tests verify:
# 1. GET /api/user/sanctity?username=<name> - Lookup user sanctity
# 2. Authorization checks (admin-only)
# 3. User lookup with underscore-to-space conversion
# 4. POST /api/user/edit - Profile editing including bookmark management
#############################################################################

# Get test users
my $test_user = $DB->getNode("normaluser1", "user");
ok($test_user, "Got test user normaluser1");

my $root = $DB->getNode("root", "user");
ok($root, "Got root user");

# Helper: Create a simple mock request object (for backward compatibility)
package SimpleMockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
    sub Vars { return $_[0]->{vars} || {} }
    sub request_method { return $_[0]->{method} || 'GET' }
}

# Helper: Create a simple mock user object (for backward compatibility)
package SimpleMockUser {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            node_id => $args{node_id},
            user_id => $args{user_id},
            title => $args{title},
            is_admin_flag => $args{is_admin_flag} // 0,
            is_guest_flag => $args{is_guest_flag} // 0,
        };
        return bless $self, $class;
    }
}

# Create API instance
my $api = Everything::API::user->new();
ok($api, "Created user API instance");

#############################################################################
# Test 1: Non-admin user blocked
#############################################################################
subtest "Non-admin blocked" => sub {
    plan tests => 2;

    my $user = SimpleMockUser->new(
        node_id => $test_user->{node_id},
        user_id => $test_user->{user_id},
        title => $test_user->{title},
        is_admin_flag => 0
    );

    my $request = SimpleMockRequest->new(
        user => $user,
        vars => { username => 'root' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 403, "Returns 403 Forbidden");
    ok($response->[1]->{error} =~ /Admin/, "Error mentions admin requirement");
};

#############################################################################
# Test 2: Missing username parameter
#############################################################################
subtest "Missing username parameter" => sub {
    plan tests => 2;

    my $user = SimpleMockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = SimpleMockRequest->new(
        user => $user,
        vars => {}  # No username
    );

    my $response = $api->sanctity($request);

    is($response->[0], 400, "Returns 400 Bad Request");
    ok($response->[1]->{error} =~ /Username parameter required/, "Error mentions missing parameter");
};

#############################################################################
# Test 3: User not found
#############################################################################
subtest "User not found" => sub {
    plan tests => 2;

    my $user = SimpleMockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = SimpleMockRequest->new(
        user => $user,
        vars => { username => 'nonexistent_user_12345' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 404, "Returns 404 Not Found");
    ok($response->[1]->{error} =~ /not found/, "Error mentions user not found");
};

#############################################################################
# Test 4: Successful lookup
#############################################################################
subtest "Successful lookup" => sub {
    plan tests => 4;

    my $user = SimpleMockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = SimpleMockRequest->new(
        user => $user,
        vars => { username => 'root' }
    );

    my $response = $api->sanctity($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Success is true");
    is($response->[1]->{username}, 'root', "Returns correct username");
    ok(defined $response->[1]->{sanctity}, "Returns sanctity value");
};

#############################################################################
# Test 5: Lookup with underscore-to-space conversion
#############################################################################
subtest "Underscore to space conversion" => sub {
    plan tests => 2;

    # Create a user with space in name if it doesn't exist
    my $spaced_user = $DB->getNode("Cool Man Eddie", "user");
    skip "Cool Man Eddie not in database", 2 unless $spaced_user;

    my $user = SimpleMockUser->new(
        node_id => $root->{node_id},
        user_id => $root->{user_id},
        title => $root->{title},
        is_admin_flag => 1
    );

    my $request = SimpleMockRequest->new(
        user => $user,
        vars => { username => 'Cool_Man_Eddie' }  # Using underscores
    );

    my $response = $api->sanctity($request);

    is($response->[0], 200, "Returns 200 OK with underscore conversion");
    is($response->[1]->{username}, 'Cool Man Eddie', "Returns name with spaces");
};

#############################################################################
# Test 6: edit_profile - Guest user blocked
#############################################################################
subtest "edit_profile - Guest user blocked" => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        is_guest_flag => 1,
        request_method => 'POST',
        postdata => { node_id => $test_user->{node_id} }
    );

    my $response = $api->edit_profile($request);

    is($response->[0], 200, "Returns 200 OK (with error in body)");
    is($response->[1]->{success}, 0, "Success is false for guest");
};

#############################################################################
# Test 7: edit_profile - Missing node_id
#############################################################################
subtest "edit_profile - Missing node_id" => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        request_method => 'POST',
        postdata => { realname => 'Test Name' }  # No node_id
    );

    my $response = $api->edit_profile($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false when node_id missing");
};

#############################################################################
# Test 8: edit_profile - Cannot edit other user's profile
#############################################################################
subtest "edit_profile - Cannot edit other user's profile" => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => { node_id => $root->{node_id}, realname => 'Hacked Name' }
    );

    my $response = $api->edit_profile($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 0, "Success is false when editing other user");
};

#############################################################################
# Test 9: edit_profile - Bookmark reordering updates food column
#############################################################################
subtest "edit_profile - Bookmark reordering" => sub {
    # This test verifies the bookmark_order parameter updates the food column
    # We need to set up bookmarks first, then test reordering

    # Get the bookmark linktype
    my $bookmark_linktype = $DB->getNode('bookmark', 'linktype');
    skip "Bookmark linktype not found", 3 unless $bookmark_linktype;

    # Find some nodes to bookmark for testing
    my $node1 = $DB->getNode("root", "user");
    my $node2 = $DB->getNode("Cool Man Eddie", "user");
    skip "Need at least 2 users for bookmark test", 3 unless $node1 && $node2;

    my $user_id = $test_user->{node_id};
    my $linktype_id = $bookmark_linktype->{node_id};

    # Clear any existing bookmarks for test user
    $DB->sqlDelete('links', "from_node=$user_id AND linktype=$linktype_id");

    # Add two bookmarks with known ordering
    $DB->sqlInsert('links', {
        from_node => $user_id,
        to_node => $node1->{node_id},
        linktype => $linktype_id,
        food => 10
    });
    $DB->sqlInsert('links', {
        from_node => $user_id,
        to_node => $node2->{node_id},
        linktype => $linktype_id,
        food => 20
    });

    # Verify bookmarks exist
    my $count = $DB->sqlSelect('count(*)', 'links',
        "from_node=$user_id AND linktype=$linktype_id");
    is($count, 2, "Set up 2 test bookmarks");

    # Create request to reorder - put node2 first
    my $request = MockRequest->new(
        node_id => $user_id,
        title => $test_user->{title},
        nodedata => $test_user,
        is_guest_flag => 0,
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => {
            node_id => $user_id,
            bookmark_order => [$node2->{node_id}, $node1->{node_id}]
        }
    );

    my $response = $api->edit_profile($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Bookmark reorder succeeded");

    # Verify the order was updated
    my $food1 = $DB->sqlSelect('food', 'links',
        "from_node=$user_id AND to_node=" . $node1->{node_id} . " AND linktype=$linktype_id");
    my $food2 = $DB->sqlSelect('food', 'links',
        "from_node=$user_id AND to_node=" . $node2->{node_id} . " AND linktype=$linktype_id");

    ok($food2 < $food1, "Node2 now has lower food value (comes first)");

    # Clean up test bookmarks
    $DB->sqlDelete('links', "from_node=$user_id AND linktype=$linktype_id");
};

#############################################################################
# Test 10: edit_profile - Bookmark removal
#############################################################################
subtest "edit_profile - Bookmark removal" => sub {
    # Get the bookmark linktype
    my $bookmark_linktype = $DB->getNode('bookmark', 'linktype');
    skip "Bookmark linktype not found", 3 unless $bookmark_linktype;

    # Find a node to bookmark
    my $node_to_bookmark = $DB->getNode("root", "user");
    skip "Need a user node for bookmark test", 3 unless $node_to_bookmark;

    my $user_id = $test_user->{node_id};
    my $linktype_id = $bookmark_linktype->{node_id};
    my $to_node_id = $node_to_bookmark->{node_id};

    # Clear any existing bookmark
    $DB->sqlDelete('links',
        "from_node=$user_id AND to_node=$to_node_id AND linktype=$linktype_id");

    # Add a bookmark
    $DB->sqlInsert('links', {
        from_node => $user_id,
        to_node => $to_node_id,
        linktype => $linktype_id,
        food => 10
    });

    # Verify bookmark exists
    my $exists = $DB->sqlSelect('from_node', 'links',
        "from_node=$user_id AND to_node=$to_node_id AND linktype=$linktype_id");
    is($exists, $user_id, "Test bookmark created");

    # Create request to remove the bookmark
    my $request = MockRequest->new(
        node_id => $user_id,
        title => $test_user->{title},
        nodedata => $test_user,
        is_guest_flag => 0,
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => {
            node_id => $user_id,
            bookmark_remove => [$to_node_id]
        }
    );

    my $response = $api->edit_profile($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Bookmark removal succeeded");

    # Verify bookmark was removed
    my $still_exists = $DB->sqlSelect('from_node', 'links',
        "from_node=$user_id AND to_node=$to_node_id AND linktype=$linktype_id");
    ok(!$still_exists, "Bookmark was removed from database");
};

#############################################################################
# Test 11: Everything::Node::user json_display handles non-numeric level gracefully
#############################################################################
subtest "json_display handles non-numeric values" => sub {
    # This test verifies that json_display doesn't produce warnings
    # when numeric fields contain non-numeric values (e.g., level = ' ')

    my $user_node = $APP->node_by_id($test_user->{node_id});
    ok($user_node, "Got user node object");

    # Call json_display - it should not produce warnings even if
    # some values like level are non-numeric
    my $warnings = '';
    {
        local $SIG{__WARN__} = sub { $warnings .= $_[0] };
        my $display = $user_node->json_display();
        ok($display, "json_display returns data");
        ok(defined($display->{level}), "level is defined");
        ok(defined($display->{experience}), "experience is defined");
        ok(defined($display->{numwriteups}), "numwriteups is defined");
    }

    # Check no numeric conversion warnings
    unlike($warnings, qr/isn't numeric/i, "No 'isn't numeric' warnings from json_display");
};

done_testing();
