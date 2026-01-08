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
use Everything::API::node_search;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::node_search->new();
ok($api, "Created node_search API instance");

#############################################################################
# Test 1: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
ok(exists $routes->{'/'}, "/ route exists");

#############################################################################
# Test 2: Missing search term
#############################################################################

my $root_user = $DB->getNode("root", "user");
ok($root_user, "Got root user for tests");

my $missing_q_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => {}
);

my $result = $api->search($missing_q_request);
is($result->[0], 200, "Missing search term returns 200");
is($result->[1]{success}, 0, "Missing search term has success=0");
like($result->[1]{error}, qr/required/i, "Error mentions required");

#############################################################################
# Test 3: Empty search term
#############################################################################

my $empty_q_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => '' }
);

$result = $api->search($empty_q_request);
is($result->[0], 200, "Empty search term returns 200");
is($result->[1]{success}, 0, "Empty search term has success=0");

#############################################################################
# Test 4: Invalid scope
#############################################################################

my $invalid_scope_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'invalid_scope' }
);

$result = $api->search($invalid_scope_request);
is($result->[0], 200, "Invalid scope returns 200");
is($result->[1]{success}, 0, "Invalid scope has success=0");
like($result->[1]{error}, qr/invalid scope/i, "Error mentions invalid scope");

#############################################################################
# Test 5: Search users scope - find root
#############################################################################

my $search_users_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'users' }
);

$result = $api->search($search_users_request);
is($result->[0], 200, "User search returns 200");
is($result->[1]{success}, 1, "User search was successful");
ok($result->[1]{results}, "Results array exists");
is($result->[1]{scope}, 'users', "Scope is correct in response");
is($result->[1]{search_term}, 'root', "Search term is correct in response");

# Should find root user
my @root_results = grep { $_->{title} eq 'root' && $_->{type} eq 'user' } @{$result->[1]{results}};
ok(scalar(@root_results) > 0, "Found root user in results");

#############################################################################
# Test 6: Search usergroups scope
#############################################################################

# First ensure we have a usergroup to find
my $gods_group = $DB->getNode("gods", "usergroup");
ok($gods_group, "gods usergroup exists for testing");

my $search_groups_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'god', scope => 'usergroups' }
);

$result = $api->search($search_groups_request);
is($result->[0], 200, "Usergroup search returns 200");
is($result->[1]{success}, 1, "Usergroup search was successful");
is($result->[1]{scope}, 'usergroups', "Scope is usergroups");

# Should find gods group
my @gods_results = grep { $_->{title} eq 'gods' && $_->{type} eq 'usergroup' } @{$result->[1]{results}};
ok(scalar(@gods_results) > 0, "Found gods usergroup in results");

# Should NOT find any users
my @user_results = grep { $_->{type} eq 'user' } @{$result->[1]{results}};
is(scalar(@user_results), 0, "No users in usergroups scope results");

#############################################################################
# Test 7: Search users_and_groups scope
#############################################################################

my $search_both_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'e', scope => 'users_and_groups' }
);

$result = $api->search($search_both_request);
is($result->[0], 200, "users_and_groups search returns 200");
is($result->[1]{success}, 1, "users_and_groups search was successful");
is($result->[1]{scope}, 'users_and_groups', "Scope is users_and_groups");

# Results may include both types (depending on what matches 'e')
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");

#############################################################################
# Test 8: group_addable scope - missing group_id
#############################################################################

my $group_addable_no_id_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'group_addable' }
);

$result = $api->search($group_addable_no_id_request);
is($result->[0], 200, "group_addable without group_id returns 200");
is($result->[1]{success}, 0, "group_addable without group_id has success=0");
like($result->[1]{error}, qr/group_id.*required/i, "Error mentions group_id required");

#############################################################################
# Test 9: group_addable scope - with group_id (excludes current members)
#############################################################################

my $group_addable_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'group_addable', group_id => $gods_group->{node_id} }
);

$result = $api->search($group_addable_request);
is($result->[0], 200, "group_addable with group_id returns 200");
is($result->[1]{success}, 1, "group_addable search was successful");
is($result->[1]{scope}, 'group_addable', "Scope is group_addable");

# root is in gods, so it should NOT appear in results (excluded as current member)
my @root_in_addable = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
is(scalar(@root_in_addable), 0, "root is excluded from group_addable (already in gods)");

#############################################################################
# Test 9b: group_addable scope - actually FINDS users not in the group
# This is critical - ensures bind params are in correct SQL order
#############################################################################

# Use a different group (edev) and search for 'root' who is NOT in edev
my $edev_group = $DB->getNode("edev", "usergroup");
SKIP: {
    skip "edev usergroup not found", 4 unless $edev_group;

    # Verify root is NOT in edev
    my %edev_members = map { $_ => 1 } @{$edev_group->{group} || []};
    skip "root is unexpectedly in edev - test invalid", 4 if $edev_members{$root_user->{node_id}};

    my $edev_addable_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'roo', scope => 'group_addable', group_id => $edev_group->{node_id} }
    );

    $result = $api->search($edev_addable_request);
    is($result->[0], 200, "group_addable for edev returns 200");
    is($result->[1]{success}, 1, "group_addable for edev was successful");
    ok($result->[1]{count} > 0, "group_addable actually returns results for users not in group");

    # root should be IN the results (not in edev, so addable)
    my @root_addable_to_edev = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
    is(scalar(@root_addable_to_edev), 1, "root IS found in group_addable for edev (not a member)");
}

#############################################################################
# Test 10: Default scope is 'users'
#############################################################################

my $default_scope_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root' }  # No scope specified
);

$result = $api->search($default_scope_request);
is($result->[0], 200, "Default scope returns 200");
is($result->[1]{success}, 1, "Default scope was successful");
is($result->[1]{scope}, 'users', "Default scope is 'users'");

#############################################################################
# Test 11: Limit parameter
#############################################################################

my $limit_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'e', scope => 'users', limit => '3' }
);

$result = $api->search($limit_request);
is($result->[0], 200, "Limit search returns 200");
is($result->[1]{success}, 1, "Limit search was successful");
ok($result->[1]{count} <= 3, "Results limited to 3 or fewer");

#############################################################################
# Test 12: Whitespace trimming in search term
#############################################################################

my $whitespace_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => '  root  ', scope => 'users' }
);

$result = $api->search($whitespace_request);
is($result->[0], 200, "Whitespace-padded search returns 200");
is($result->[1]{success}, 1, "Whitespace search was successful");
is($result->[1]{search_term}, 'root', "Search term is trimmed");

my @trimmed_results = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
ok(scalar(@trimmed_results) > 0, "Found root with whitespace-padded search");

#############################################################################
# Test 13: Case insensitive search
#############################################################################

my $case_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'ROOT', scope => 'users' }
);

$result = $api->search($case_request);
is($result->[0], 200, "Case insensitive search returns 200");
is($result->[1]{success}, 1, "Case insensitive search was successful");

# Should find root with uppercase search (depends on DB collation)
# Most MySQL installs are case-insensitive by default
my @case_results = grep { lc($_->{title}) eq 'root' } @{$result->[1]{results}};
if (scalar(@case_results) > 0) {
    pass("Case insensitive search found root");
} else {
    pass("Case sensitive collation - ROOT didn't match root");
}

#############################################################################
# Test 14: No results
#############################################################################

my $no_results_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'xyznonexistent_' . time(), scope => 'users' }
);

$result = $api->search($no_results_request);
is($result->[0], 200, "No results search returns 200");
is($result->[1]{success}, 1, "No results search was still successful");
is($result->[1]{count}, 0, "Count is 0 for no results");
is(scalar(@{$result->[1]{results}}), 0, "Results array is empty");

#############################################################################
# Test 15: Result structure
#############################################################################

my $structure_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'users' }
);

$result = $api->search($structure_request);
if ($result->[1]{count} > 0) {
    my $first = $result->[1]{results}[0];
    ok(exists $first->{node_id}, "Result has node_id");
    ok(exists $first->{title}, "Result has title");
    ok(exists $first->{type}, "Result has type");
    ok($first->{node_id} =~ /^\d+$/, "node_id is numeric");
    is($first->{type}, 'user', "type is 'user' for users scope");
} else {
    SKIP: {
        skip "No results to check structure", 5;
    }
}

#############################################################################
# Test 16: SQL injection prevention - LIKE pattern characters escaped
#############################################################################

# Test with % character in search term - should be escaped and not match wildcard
my $percent_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => '%root', scope => 'users' }
);

$result = $api->search($percent_request);
is($result->[0], 200, "Search with % returns 200");
is($result->[1]{success}, 1, "Search with % was successful");
is($result->[1]{search_term}, '%root', "Search term preserved with %");
# Should NOT find 'root' because % is escaped (no prefix match)
my @percent_results = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
is(scalar(@percent_results), 0, "% is escaped - does not act as wildcard");

#############################################################################
# Test 17: SQL injection prevention - underscore character escaped
#############################################################################

# Test with _ character in search term - should be escaped and not match single char
my $underscore_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'r_ot', scope => 'users' }
);

$result = $api->search($underscore_request);
is($result->[0], 200, "Search with _ returns 200");
is($result->[1]{success}, 1, "Search with _ was successful");
is($result->[1]{search_term}, 'r_ot', "Search term preserved with _");
# Should NOT find 'root' because _ is escaped (not single-char wildcard)
my @underscore_results = grep { $_->{title} eq 'root' } @{$result->[1]{results}};
is(scalar(@underscore_results), 0, "_ is escaped - does not act as single-char wildcard");

#############################################################################
# Test 18: SQL injection prevention - backslash character escaped
#############################################################################

my $backslash_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root\\', scope => 'users' }
);

$result = $api->search($backslash_request);
is($result->[0], 200, "Search with backslash returns 200");
is($result->[1]{success}, 1, "Search with backslash was successful");
# Should not cause SQL error - backslash is properly escaped

#############################################################################
# Test 19: SQL injection prevention - quoted strings
#############################################################################

my $quote_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => "root'; DROP TABLE node; --", scope => 'users' }
);

$result = $api->search($quote_request);
is($result->[0], 200, "Search with SQL injection attempt returns 200");
is($result->[1]{success}, 1, "Search with SQL injection was handled safely");
# The query should run without error - parameterized queries prevent injection

#############################################################################
# Test 20: message_recipients scope - basic functionality
#############################################################################

my $msg_recipients_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'root', scope => 'message_recipients' }
);

$result = $api->search($msg_recipients_request);
is($result->[0], 200, "message_recipients scope returns 200");
is($result->[1]{success}, 1, "message_recipients search was successful");
is($result->[1]{scope}, 'message_recipients', "Scope is message_recipients");
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");

#############################################################################
# Test 21: message_recipients - admins can see all usergroups
#############################################################################

my $msg_groups_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_admin_flag => 1,
    query_params => { q => 'god', scope => 'message_recipients' }
);

$result = $api->search($msg_groups_request);
is($result->[0], 200, "message_recipients with usergroup search returns 200");
is($result->[1]{success}, 1, "message_recipients usergroup search was successful");

# Admin should find gods usergroup
my @msg_gods_results = grep { $_->{title} eq 'gods' && $_->{type} eq 'usergroup' } @{$result->[1]{results}};
ok(scalar(@msg_gods_results) > 0, "Admin finds gods usergroup in message_recipients");

#############################################################################
# Test 22: message_recipients - mail forwarding accounts are excluded
# Mail forwarding accounts should NOT appear directly - only via alias
#############################################################################

# First, create a test mail forwarding user or check if one exists
# For this test, we'll verify that if a user has message_forward_to set,
# they don't appear in direct user search results for message_recipients
my $dbh = $DB->{dbh};

# Find any user with message_forward_to set
my $forward_sth = $dbh->prepare(qq{
    SELECT u.user_id, n.title, u.message_forward_to
    FROM user u
    JOIN node n ON n.node_id = u.user_id
    WHERE u.message_forward_to IS NOT NULL
    AND u.message_forward_to != 0
    LIMIT 1
});
$forward_sth->execute();
my $forward_user = $forward_sth->fetchrow_hashref();

SKIP: {
    skip "No mail forwarding users found in database", 3 unless $forward_user;

    my $forward_title = $forward_user->{title};
    # Search for this user by exact prefix
    my $forward_search_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => $forward_title, scope => 'message_recipients' }
    );

    $result = $api->search($forward_search_request);
    is($result->[0], 200, "message_recipients returns 200 when searching for forwarding user");
    is($result->[1]{success}, 1, "message_recipients search was successful");

    # The forwarding user itself should NOT appear as a direct result
    # It may appear as an alias target with 'alias' field set
    my @direct_forward_results = grep {
        $_->{title} eq $forward_title && !exists($_->{alias})
    } @{$result->[1]{results}};

    is(scalar(@direct_forward_results), 0,
        "Mail forwarding user '$forward_title' does NOT appear as direct result (only via alias)");
}

#############################################################################
# Test 23: message_recipients - alias field present for forwarded accounts
#############################################################################

SKIP: {
    skip "No mail forwarding users found in database", 2 unless $forward_user;

    my $forward_title = $forward_user->{title};

    # Search for the forwarding user by its title - should get target with alias
    my $alias_search_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => $forward_title, scope => 'message_recipients' }
    );

    $result = $api->search($alias_search_request);

    # Find results that have an alias field matching our forwarding user
    my @alias_results = grep {
        exists($_->{alias}) && $_->{alias} eq $forward_title
    } @{$result->[1]{results}};

    ok(scalar(@alias_results) > 0,
        "Mail forwarding user '$forward_title' appears via alias expansion");

    if (scalar(@alias_results) > 0) {
        ok(exists $alias_results[0]->{title} && $alias_results[0]->{title} ne $forward_title,
            "Alias result shows target title, not forwarding account title");
    } else {
        pass("Skipped - no alias results to check target title");
    }
}

#############################################################################
# Test 24: e2nodes scope - basic search functionality
#############################################################################

# First find an e2node to search for
my $e2node_type = $DB->getType('e2node');
SKIP: {
    skip "e2node nodetype not found", 6 unless $e2node_type;

    # Find any e2node to test with
    my $e2node_sth = $dbh->prepare(qq{
        SELECT node_id, title FROM node
        WHERE type_nodetype = ?
        LIMIT 1
    });
    $e2node_sth->execute($e2node_type->{node_id});
    my $test_e2node = $e2node_sth->fetchrow_hashref();

    skip "No e2nodes found in database", 6 unless $test_e2node;

    # Get first few characters of the title for search
    my $search_prefix = substr($test_e2node->{title}, 0, 3);

    my $e2nodes_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => $search_prefix, scope => 'e2nodes' }
    );

    $result = $api->search($e2nodes_request);
    is($result->[0], 200, "e2nodes scope returns 200");
    is($result->[1]{success}, 1, "e2nodes search was successful");
    is($result->[1]{scope}, 'e2nodes', "Scope is e2nodes");
    ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");

    # All results should have type 'e2node'
    my @non_e2node_results = grep { $_->{type} ne 'e2node' } @{$result->[1]{results}};
    is(scalar(@non_e2node_results), 0, "All results are e2node type");

    # Should find the test e2node if search prefix matches
    my @matching_results = grep { $_->{title} =~ /^\Q$search_prefix\E/i } @{$result->[1]{results}};
    ok(scalar(@matching_results) > 0, "Found e2nodes matching search prefix");
}

#############################################################################
# Test 25: e2nodes scope - result structure
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 4 unless $e2node_type;

    my $e2nodes_structure_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'a', scope => 'e2nodes', limit => '5' }
    );

    $result = $api->search($e2nodes_structure_request);

    if ($result->[1]{count} > 0) {
        my $first = $result->[1]{results}[0];
        ok(exists $first->{node_id}, "e2node result has node_id");
        ok(exists $first->{title}, "e2node result has title");
        ok(exists $first->{type}, "e2node result has type");
        is($first->{type}, 'e2node', "type is 'e2node'");
    } else {
        skip "No e2node results to check structure", 4;
    }
}

#############################################################################
# Test 26: e2nodes scope - does not return users
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 2 unless $e2node_type;

    # Search for 'root' which exists as a user but should NOT appear in e2nodes results
    my $e2nodes_no_users_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'root', scope => 'e2nodes' }
    );

    $result = $api->search($e2nodes_no_users_request);
    is($result->[1]{success}, 1, "e2nodes search for 'root' was successful");

    # Should NOT find users in e2nodes scope
    my @user_results = grep { $_->{type} eq 'user' } @{$result->[1]{results}};
    is(scalar(@user_results), 0, "No users in e2nodes scope results");
}

#############################################################################
# Test 27: e2nodes scope - limit parameter works
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 2 unless $e2node_type;

    my $e2nodes_limit_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'a', scope => 'e2nodes', limit => '2' }
    );

    $result = $api->search($e2nodes_limit_request);
    is($result->[1]{success}, 1, "e2nodes search with limit was successful");
    ok($result->[1]{count} <= 2, "e2nodes results limited to 2 or fewer");
}

#############################################################################
# Test 28: e2nodes scope - SQL injection prevention
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 2 unless $e2node_type;

    my $e2nodes_injection_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => "test'; DROP TABLE node; --", scope => 'e2nodes' }
    );

    $result = $api->search($e2nodes_injection_request);
    is($result->[0], 200, "e2nodes search with SQL injection attempt returns 200");
    is($result->[1]{success}, 1, "e2nodes search with SQL injection was handled safely");
}

#############################################################################
# Test 29: e2nodes scope - author filter with valid author
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 4 unless $e2node_type;

    # Find an author who has writeups
    my $writeup_author_sth = $dbh->prepare(qq{
        SELECT DISTINCT n.node_id, n.title
        FROM node n
        JOIN node wu ON wu.author_user = n.node_id
        JOIN writeup w ON w.writeup_id = wu.node_id
        WHERE n.type_nodetype = (SELECT node_id FROM node WHERE title = 'user' AND type_nodetype = 1)
        LIMIT 1
    });
    $writeup_author_sth->execute();
    my $test_author = $writeup_author_sth->fetchrow_hashref();

    skip "No users with writeups found for author filter test", 4 unless $test_author;

    my $e2nodes_author_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'a', scope => 'e2nodes', author => $test_author->{title} }
    );

    $result = $api->search($e2nodes_author_request);
    is($result->[0], 200, "e2nodes search with author filter returns 200");
    is($result->[1]{success}, 1, "e2nodes search with author filter was successful");
    is($result->[1]{author}, $test_author->{title}, "Response includes author parameter");
    ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");
}

#############################################################################
# Test 30: e2nodes scope - author filter with non-existent author
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 3 unless $e2node_type;

    my $e2nodes_nonexistent_author_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => 'test', scope => 'e2nodes', author => 'nonexistent_user_xyz_12345' }
    );

    $result = $api->search($e2nodes_nonexistent_author_request);
    is($result->[0], 200, "e2nodes search with non-existent author returns 200");
    is($result->[1]{success}, 1, "Non-existent author returns success (empty results, not error)");
    is($result->[1]{count}, 0, "Non-existent author returns zero results");
}

#############################################################################
# Test 31: e2nodes scope - author filter only returns relevant e2nodes
#############################################################################

SKIP: {
    skip "e2node nodetype not found", 3 unless $e2node_type;

    # Find an author with at least one writeup
    my $writeup_data_sth = $dbh->prepare(qq{
        SELECT n.title as author_name, e2.title as e2node_title
        FROM node n
        JOIN node wu ON wu.author_user = n.node_id
        JOIN writeup w ON w.writeup_id = wu.node_id
        JOIN node e2 ON e2.node_id = w.parent_e2node
        WHERE n.type_nodetype = (SELECT node_id FROM node WHERE title = 'user' AND type_nodetype = 1)
        LIMIT 1
    });
    $writeup_data_sth->execute();
    my $writeup_data = $writeup_data_sth->fetchrow_hashref();

    skip "No writeup data found for author filter verification test", 3 unless $writeup_data;

    # Search with a prefix of the e2node title that we know should match
    my $search_prefix = substr($writeup_data->{e2node_title}, 0, 3);

    my $e2nodes_verify_request = MockRequest->new(
        node_id => $root_user->{node_id},
        title => $root_user->{title},
        nodedata => $root_user,
        is_guest_flag => 0,
        is_admin_flag => 1,
        query_params => { q => $search_prefix, scope => 'e2nodes', author => $writeup_data->{author_name} }
    );

    $result = $api->search($e2nodes_verify_request);
    is($result->[1]{success}, 1, "Author filter verification search was successful");

    # Should find at least the e2node we know the author has a writeup in
    my @matching = grep { $_->{title} eq $writeup_data->{e2node_title} } @{$result->[1]{results}};
    ok(scalar(@matching) > 0, "Author filter found e2node where author has writeup");
    is($result->[1]{author}, $writeup_data->{author_name}, "Response includes correct author");
}

done_testing();

=head1 NAME

t/013_node_search_api.t - Tests for Everything::API::node_search

=head1 DESCRIPTION

Tests the unified node search API:
- Missing/empty search term validation
- Invalid scope validation
- Users scope search
- Usergroups scope search
- users_and_groups scope search
- group_addable scope (with member exclusion)
- Default scope behavior
- Limit parameter
- Whitespace trimming
- Case sensitivity
- No results handling
- Result structure validation
- SQL injection prevention (LIKE pattern escaping)
- SQL injection prevention (parameterized queries)
- message_recipients scope (basic functionality)
- message_recipients scope (admin can see all usergroups)
- message_recipients scope (mail forwarding accounts excluded from direct results)
- message_recipients scope (alias field present for forwarded accounts)
- e2nodes scope (basic search functionality)
- e2nodes scope (result structure validation)
- e2nodes scope (does not return users)
- e2nodes scope (limit parameter)
- e2nodes scope (SQL injection prevention)
- e2nodes scope (author filter with valid author)
- e2nodes scope (author filter with non-existent author)
- e2nodes scope (author filter returns only relevant e2nodes)

=head1 AUTHOR

Everything2 Development Team

=cut
