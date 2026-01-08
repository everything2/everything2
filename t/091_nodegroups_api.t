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
use Everything::API::nodegroups;
use Everything::API::node_search;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::nodegroups->new();
ok($api, "Created nodegroups API instance");

my $search_api = Everything::API::node_search->new();
ok($search_api, "Created node_search API instance");

#############################################################################
# Setup - Get test users and find/create a nodegroup
#############################################################################

my $root_user = $DB->getNode("root", "user");
ok($root_user, "Got root user for tests");

my $nm1 = $DB->getNode("normaluser1", "user");
ok($nm1, "Got normaluser1 for tests");

# Find an existing nodegroup or skip tests
my $dbh = $DB->{dbh};
my $sth = $dbh->prepare(qq{
    SELECT n.node_id, n.title
    FROM node n
    JOIN node nt ON n.type_nodetype = nt.node_id
    WHERE nt.title = 'nodegroup'
    LIMIT 1
});
$sth->execute();
my $test_nodegroup_row = $sth->fetchrow_hashref();

my $test_nodegroup;
my $nodegroup_id;
my $cleanup_nodegroup = 0;

if ($test_nodegroup_row) {
    $test_nodegroup = $DB->getNodeById($test_nodegroup_row->{node_id});
    $nodegroup_id = $test_nodegroup->{node_id};
    ok($test_nodegroup, "Found existing nodegroup: $test_nodegroup->{title}");
} else {
    # Create a test nodegroup
    my $nodegroup_type = $DB->getNode("nodegroup", "nodetype");
    if ($nodegroup_type) {
        my $new_id = $DB->insertNode("API Test Nodegroup " . time(), $nodegroup_type->{node_id}, $root_user);
        if ($new_id) {
            $test_nodegroup = $DB->getNodeById($new_id);
            $nodegroup_id = $new_id;
            $cleanup_nodegroup = 1;
            ok($test_nodegroup, "Created test nodegroup");
        }
    }
}

SKIP: {
    skip "No nodegroup available for testing", 50 unless $test_nodegroup;

    #############################################################################
    # Test 1: Routes check
    #############################################################################

    my $routes = $api->routes();
    ok($routes, "Routes defined");
    ok(exists $routes->{':id/action/addnode'}, "addnode route exists");
    ok(exists $routes->{':id/action/removenode'}, "removenode route exists");
    ok(exists $routes->{':id/action/reorder'}, "reorder route exists");

    #############################################################################
    # Test 2: Permission check - Guest cannot manage nodegroup
    #############################################################################

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        nodedata => {},
        is_guest_flag => 1,
        is_admin_flag => 0,
        postdata => { node_ids => [$root_user->{node_id}] }
    );

    my $result = $api->addnode($guest_request, $nodegroup_id);
    is($result->[0], 200, "Guest addnode returns 200 with error");
    is($result->[1]{success}, 0, "Guest addnode has success=0");
    like($result->[1]{error}, qr/permission denied/i, "Guest gets permission denied");

    #############################################################################
    # Test 3: Permission check - Non-admin cannot manage nodegroup
    #############################################################################

    my $non_admin_request = MockRequest->new(
        node_id => $nm1->{node_id},
        title => $nm1->{title},
        nodedata => $nm1,
        is_guest_flag => 0,
        is_admin_flag => 0,
        postdata => { node_ids => [$root_user->{node_id}] }
    );

    $result = $api->addnode($non_admin_request, $nodegroup_id);
    is($result->[0], 200, "Non-admin addnode returns 200 with error");
    is($result->[1]{success}, 0, "Non-admin addnode has success=0");
    like($result->[1]{error}, qr/permission denied/i, "Non-admin gets permission denied");

    #############################################################################
    # Test 4: Add node - Missing node_ids parameter
    #############################################################################

    my $missing_ids_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { wrong_field => [123] }
    );

    $result = $api->addnode($missing_ids_request, $nodegroup_id);
    is($result->[0], 200, "Missing node_ids returns 200 with error");
    is($result->[1]{success}, 0, "Missing node_ids has success=0");
    like($result->[1]{error}, qr/node_ids/i, "Error mentions node_ids");

    #############################################################################
    # Test 5: Add node - Invalid node_ids format (not an array)
    #############################################################################

    my $invalid_format_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { node_ids => 123 }  # Should be array
    );

    $result = $api->addnode($invalid_format_request, $nodegroup_id);
    is($result->[0], 200, "Invalid node_ids format returns 200 with error");
    is($result->[1]{success}, 0, "Invalid format has success=0");

    #############################################################################
    # Test 6: Add node - Success (admin adds a node)
    #############################################################################

    # Find a document node to add
    my $doc_sth = $dbh->prepare(qq{
        SELECT n.node_id, n.title
        FROM node n
        JOIN node nt ON n.type_nodetype = nt.node_id
        WHERE nt.title = 'document'
        LIMIT 1
    });
    $doc_sth->execute();
    my $doc_row = $doc_sth->fetchrow_hashref();

    SKIP: {
        skip "No document node found for testing", 5 unless $doc_row;

        my $doc_node = $DB->getNodeById($doc_row->{node_id});
        ok($doc_node, "Found document node for testing: $doc_node->{title}");

        my $add_request = MockRequest->new(
            node_id => $root_user->{node_id},
            title => $root_user->{title},
            nodedata => $root_user,
            is_guest_flag => 0,
            is_admin_flag => 1,
            postdata => { node_ids => [$doc_node->{node_id}] }
        );

        $result = $api->addnode($add_request, $nodegroup_id);
        is($result->[0], 200, "Add node returns 200");
        ok($result->[1]{success}, "Add node was successful");
        ok(ref($result->[1]{group}) eq 'ARRAY', "Result contains group array");

        # Verify the group contains type info
        if (scalar(@{$result->[1]{group}}) > 0) {
            my $first_member = $result->[1]{group}[0];
            ok(exists $first_member->{type}, "Group member has type field");
        } else {
            pass("Group updated (member count may have changed)");
        }

        #############################################################################
        # Test 7: Remove node - Success
        #############################################################################

        my $remove_request = MockRequest->new(
            node_id => $root_user->{node_id},
            title => $root_user->{title},
            nodedata => $root_user,
            is_guest_flag => 0,
            is_admin_flag => 1,
            postdata => { node_ids => [$doc_node->{node_id}] }
        );

        $result = $api->removenode($remove_request, $nodegroup_id);
        is($result->[0], 200, "Remove node returns 200");
        ok($result->[1]{success}, "Remove node was successful");
        ok(ref($result->[1]{group}) eq 'ARRAY', "Remove result contains group array");
    }

    #############################################################################
    # Test 8: Reorder - Invalid format (not an array)
    #############################################################################

    my $reorder_invalid_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { wrong => 'format' }  # Should be array directly
    );

    $result = $api->reorder($reorder_invalid_request, $nodegroup_id);
    is($result->[0], 200, "Reorder with invalid format returns 200 with error");
    is($result->[1]{success}, 0, "Invalid reorder has success=0");
    like($result->[1]{error}, qr/array/i, "Error mentions array");

    #############################################################################
    # Test 9: Reorder - Node not in group
    #############################################################################

    my $reorder_not_in_group_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => [999999999]  # Non-existent node
    );

    $result = $api->reorder($reorder_not_in_group_request, $nodegroup_id);
    is($result->[0], 200, "Reorder with non-member returns 200 with error");
    is($result->[1]{success}, 0, "Reorder non-member has success=0");
    like($result->[1]{error}, qr/not in this group/i, "Error mentions not in group");

    #############################################################################
    # Test 10: Invalid nodegroup ID
    #############################################################################

    my $invalid_group_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        postdata => { node_ids => [123] }
    );

    $result = $api->addnode($invalid_group_request, 999999999);
    is($result->[0], 200, "Invalid group ID returns 200 with error");
    is($result->[1]{success}, 0, "Invalid group has success=0");
    like($result->[1]{error}, qr/permission denied/i, "Invalid group returns permission denied");
}

#############################################################################
# Node Search API - nodegroup_addable scope tests
#############################################################################

#############################################################################
# Test 11: nodegroup_addable scope - missing group_id
#############################################################################

my $addable_no_group_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'test', scope => 'nodegroup_addable' }
);

my $result = $search_api->search($addable_no_group_request);
is($result->[0], 200, "nodegroup_addable without group_id returns 200");
is($result->[1]{success}, 0, "nodegroup_addable without group_id has success=0");
like($result->[1]{error}, qr/group_id.*required/i, "Error mentions group_id required");

#############################################################################
# Test 12: nodegroup_addable scope - with valid group_id
#############################################################################

SKIP: {
    skip "No nodegroup available for search tests", 5 unless $test_nodegroup;

    my $addable_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'root', scope => 'nodegroup_addable', group_id => $nodegroup_id }
    );

    $result = $search_api->search($addable_request);
    is($result->[0], 200, "nodegroup_addable returns 200");
    is($result->[1]{success}, 1, "nodegroup_addable was successful");
    is($result->[1]{scope}, 'nodegroup_addable', "Scope is nodegroup_addable");
    ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");

    # Results should include type field for each node
    if (scalar(@{$result->[1]{results}}) > 0) {
        my $first_result = $result->[1]{results}[0];
        ok(exists $first_result->{type}, "Search result has type field");
    } else {
        pass("No results to check type field");
    }
}

#############################################################################
# Test 13: all_nodes scope - searches all node types
#############################################################################

my $all_nodes_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'all_nodes' }
);

$result = $search_api->search($all_nodes_request);
is($result->[0], 200, "all_nodes scope returns 200");
is($result->[1]{success}, 1, "all_nodes search was successful");
is($result->[1]{scope}, 'all_nodes', "Scope is all_nodes");
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");

# Should find root user and possibly other nodes starting with 'root'
my @root_results = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
ok(scalar(@root_results) > 0, "all_nodes found root in results");

# Should have type field
if (scalar(@{$result->[1]{results}}) > 0) {
    my $first_result = $result->[1]{results}[0];
    ok(exists $first_result->{type}, "all_nodes result has type field");
} else {
    pass("No results to check type field");
}

#############################################################################
# Cleanup
#############################################################################

if ($cleanup_nodegroup && $test_nodegroup) {
    $DB->nukeNode($test_nodegroup, $root_user);
    pass("Cleaned up test nodegroup");
}

done_testing();

=head1 NAME

t/091_nodegroups_api.t - Tests for Everything::API::nodegroups

=head1 DESCRIPTION

Tests the nodegroups API and nodegroup_addable search scope:

Nodegroups API:
- Routes check (addnode, removenode, reorder)
- Permission checks (guest, non-admin cannot manage)
- Add node (missing parameters, invalid format, success)
- Remove node (success)
- Reorder (invalid format, node not in group)
- Invalid nodegroup ID handling

Node Search API - nodegroup_addable scope:
- Missing group_id parameter
- Valid search with group_id
- Results include type field

Node Search API - all_nodes scope:
- Basic search across all node types
- Results include type field

=head1 AUTHOR

Everything2 Development Team

=cut
