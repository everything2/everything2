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
use Everything::API::registrations;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::registrations->new();
ok($api, "Created registrations API instance");

#############################################################################
# Setup - Get test users and find/create a registry
#############################################################################

my $root_user = $DB->getNode("root", "user");
ok($root_user, "Got root user for tests");

my $nm1 = $DB->getNode("normaluser1", "user");
ok($nm1, "Got normaluser1 for tests");

# Find an existing registry or create one
my $dbh = $DB->{dbh};
my $sth = $dbh->prepare(qq{
    SELECT n.node_id, n.title
    FROM node n
    JOIN node nt ON n.type_nodetype = nt.node_id
    WHERE nt.title = 'registry'
    LIMIT 1
});
$sth->execute();
my $test_registry_row = $sth->fetchrow_hashref();

my $test_registry;
my $registry_id;
my $cleanup_registry = 0;

if ($test_registry_row) {
    $test_registry = $DB->getNodeById($test_registry_row->{node_id});
    $registry_id = $test_registry->{node_id};
    ok($test_registry, "Found existing registry: $test_registry->{title}");
} else {
    # Create a test registry
    my $registry_type = $DB->getNode("registry", "nodetype");
    if ($registry_type) {
        my $new_id = $DB->insertNode("API Test Registry " . time(), $registry_type->{node_id}, $root_user);
        if ($new_id) {
            $test_registry = $DB->getNodeById($new_id);
            $registry_id = $new_id;
            $cleanup_registry = 1;
            ok($test_registry, "Created test registry");
        }
    }
}

SKIP: {
    skip "No registry available for testing", 40 unless $test_registry;

    #############################################################################
    # Test 1: Routes check
    #############################################################################

    my $routes = $api->routes();
    ok($routes, "Routes defined");
    ok(exists $routes->{':id/action/submit'}, "submit route exists");
    ok(exists $routes->{':id/action/delete'}, "delete route exists");
    ok(exists $routes->{':id/action/admin_delete'}, "admin_delete route exists");
    ok(exists $routes->{':id/entries'}, "entries route exists");

    #############################################################################
    # Test 2: Guest cannot view entries
    #############################################################################

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        nodedata => {},
        is_guest_flag => 1,
        is_admin_flag => 0
    );

    my $result = $api->get_entries($guest_request, $registry_id);
    is($result->[0], 200, "Guest get_entries returns 200");
    is($result->[1]{success}, 0, "Guest get_entries has success=0");
    like($result->[1]{error}, qr/logged in/i, "Guest gets logged in error");

    #############################################################################
    # Test 3: Guest cannot submit
    #############################################################################

    $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        nodedata => {},
        is_guest_flag => 1,
        is_admin_flag => 0,
        postdata => { data => 'test' }
    );

    $result = $api->submit($guest_request, $registry_id);
    is($result->[0], 200, "Guest submit returns 200");
    is($result->[1]{success}, 0, "Guest submit has success=0");
    like($result->[1]{error}, qr/logged in/i, "Guest gets logged in error on submit");

    #############################################################################
    # Test 4: Logged-in user can view entries
    #############################################################################

    my $user_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0
    );

    $result = $api->get_entries($user_request, $registry_id);
    is($result->[0], 200, "User get_entries returns 200");
    is($result->[1]{success}, 1, "User get_entries was successful");
    ok(ref($result->[1]{entries}) eq 'ARRAY', "entries is an array");

    #############################################################################
    # Test 5: Submit requires data field
    #############################################################################

    my $empty_submit_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => {}
    );

    $result = $api->submit($empty_submit_request, $registry_id);
    is($result->[0], 200, "Empty submit returns 200");
    is($result->[1]{success}, 0, "Empty submit has success=0");
    like($result->[1]{error}, qr/data.*required/i, "Error mentions data required");

    #############################################################################
    # Test 6: User can submit entry
    #############################################################################

    my $submit_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => {
            data => 'Test entry data',
            comments => 'Test comments',
            in_user_profile => 1
        }
    );

    $result = $api->submit($submit_request, $registry_id);
    is($result->[0], 200, "Submit returns 200");
    is($result->[1]{success}, 1, "Submit was successful");
    is($result->[1]{action}, 'created', "Action was 'created'");
    ok($result->[1]{user_entry}, "User entry returned");
    is($result->[1]{user_entry}{data}, 'Test entry data', "Data matches");
    is($result->[1]{user_entry}{comments}, 'Test comments', "Comments match");
    is($result->[1]{user_entry}{in_user_profile}, 1, "in_user_profile matches");

    #############################################################################
    # Test 7: User can update their entry
    #############################################################################

    my $update_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => {
            data => 'Updated entry data',
            comments => 'Updated comments',
            in_user_profile => 0
        }
    );

    $result = $api->submit($update_request, $registry_id);
    is($result->[0], 200, "Update returns 200");
    is($result->[1]{success}, 1, "Update was successful");
    is($result->[1]{action}, 'updated', "Action was 'updated'");
    is($result->[1]{user_entry}{data}, 'Updated entry data', "Updated data matches");

    #############################################################################
    # Test 8: Non-admin cannot admin_delete
    #############################################################################

    my $non_admin_delete_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => { user_id => $nm1->{node_id} }
    );

    $result = $api->admin_delete($non_admin_delete_request, $registry_id);
    is($result->[0], 200, "Non-admin admin_delete returns 200");
    is($result->[1]{success}, 0, "Non-admin admin_delete has success=0");
    like($result->[1]{error}, qr/permission denied/i, "Error mentions permission denied");

    #############################################################################
    # Test 9: Admin can admin_delete any user's entry
    #############################################################################

    my $admin_delete_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { user_id => $nm1->{node_id} }
    );

    $result = $api->admin_delete($admin_delete_request, $registry_id);
    is($result->[0], 200, "Admin admin_delete returns 200");
    is($result->[1]{success}, 1, "Admin admin_delete was successful");
    like($result->[1]{message}, qr/deleted/i, "Message mentions deleted");

    #############################################################################
    # Test 10: Verify entry was deleted
    #############################################################################

    $result = $api->get_entries($user_request, $registry_id);
    is($result->[0], 200, "get_entries after delete returns 200");
    ok(!$result->[1]{user_entry}, "User entry is now undefined");

    #############################################################################
    # Test 11: User can delete their own entry
    #############################################################################

    # First, create an entry again
    $submit_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => { data => 'Entry to delete' }
    );
    $api->submit($submit_request, $registry_id);

    # Now delete it
    my $delete_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0
    );

    $result = $api->delete_entry($delete_request, $registry_id);
    is($result->[0], 200, "User delete_entry returns 200");
    is($result->[1]{success}, 1, "User delete_entry was successful");
    ok(!$result->[1]{user_entry}, "User entry is undefined after delete");

    #############################################################################
    # Test 12: Invalid registry ID
    #############################################################################

    $result = $api->get_entries($user_request, 999999999);
    is($result->[0], 200, "Invalid registry returns 200");
    is($result->[1]{success}, 0, "Invalid registry has success=0");
    like($result->[1]{error}, qr/not found/i, "Error mentions not found");

    #############################################################################
    # Test 13: Data validation - too long
    #############################################################################

    my $long_data_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => { data => 'x' x 300 }
    );

    $result = $api->submit($long_data_request, $registry_id);
    is($result->[0], 200, "Long data submit returns 200");
    is($result->[1]{success}, 0, "Long data has success=0");
    like($result->[1]{error}, qr/255 characters/i, "Error mentions character limit");

    #############################################################################
    # Test 14: admin_delete requires user_id
    #############################################################################

    my $missing_user_id_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => {}
    );

    $result = $api->admin_delete($missing_user_id_request, $registry_id);
    is($result->[0], 200, "Missing user_id returns 200");
    is($result->[1]{success}, 0, "Missing user_id has success=0");
    like($result->[1]{error}, qr/user_id.*required/i, "Error mentions user_id required");
}

#############################################################################
# Cleanup
#############################################################################

# Clean up any test entries we created
$DB->sqlDelete('registration', "for_registry = $registry_id AND from_user = " . $nm1->{node_id}) if $registry_id && $nm1;

if ($cleanup_registry && $test_registry) {
    $DB->nukeNode($test_registry, $root_user);
    pass("Cleaned up test registry");
}

done_testing();

=head1 NAME

t/092_registrations_api.t - Tests for Everything::API::registrations

=head1 DESCRIPTION

Tests the registrations API:

- Routes check
- Guest access restrictions
- User entry submission (create/update)
- User entry deletion
- Admin entry deletion
- Data validation
- Error handling

=head1 AUTHOR

Everything2 Development Team

=cut
