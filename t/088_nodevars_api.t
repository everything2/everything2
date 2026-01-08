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
use Everything::API::nodevars;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::nodevars->new();
ok($api, "Created nodevars API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

# Get a test setting node to work with
my $test_setting = $DB->getNode("vote settings", "setting");
ok($test_setting, "Got test setting node");

#############################################################################
# Test: Routes check
#############################################################################

subtest 'Routes defined correctly' => sub {
    plan tests => 4;

    my $routes = $api->routes();
    ok($routes, "Routes defined");
    is($routes->{'/:id'}, 'get_vars(:id)', "get_vars route exists");
    is($routes->{'/:id/set'}, 'set_var(:id)', "set_var route exists");
    is($routes->{'/:id/delete'}, 'delete_var(:id)', "delete_var route exists");
};

#############################################################################
# Test: get_vars - guest user denied
#############################################################################

subtest 'get_vars: guest user denied' => sub {
    plan tests => 1;

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        is_admin_flag => 0
    );

    my $result = $api->get_vars($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "get_vars returns HTTP 401 for guest");
};

#############################################################################
# Test: get_vars - normal user denied
#############################################################################

subtest 'get_vars: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_vars($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "get_vars returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: get_vars - invalid node_id
#############################################################################

subtest 'get_vars: invalid node_id' => sub {
    plan tests => 4;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user
    );

    # Non-numeric node_id
    my $result1 = $api->get_vars($request, 'abc');
    is($result1->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result1->[1]{error}, qr/invalid node_id/i, "Error mentions invalid node_id");

    # Non-existent node_id
    my $result2 = $api->get_vars($request, 999999999);
    is($result2->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result2->[1]{error}, qr/not found/i, "Error mentions node not found");
};

#############################################################################
# Test: get_vars - success
#############################################################################

subtest 'get_vars: success with valid node' => sub {
    plan tests => 6;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user
    );

    my $result = $api->get_vars($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "get_vars returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{node_id}, $test_setting->{node_id}, "Correct node_id");
    is($result->[1]{node_title}, $test_setting->{title}, "Correct node title");
    is($result->[1]{node_type}, 'setting', "Correct node type");
    ok(ref($result->[1]{vars}) eq 'ARRAY', "vars is an array");
};

#############################################################################
# Test: set_var - guest user denied
#############################################################################

subtest 'set_var: guest user denied' => sub {
    plan tests => 1;

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        is_admin_flag => 0,
        postdata => { key => 'test_key', value => 'test_value' }
    );

    my $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "set_var returns HTTP 401 for guest");
};

#############################################################################
# Test: set_var - normal user denied
#############################################################################

subtest 'set_var: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user,
        postdata => { key => 'test_key', value => 'test_value' }
    );

    my $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "set_var returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: set_var - missing key
#############################################################################

subtest 'set_var: missing key' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { value => 'test_value' }
    );

    my $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result->[1]{error}, qr/key.*required/i, "Error mentions key required");
};

#############################################################################
# Test: set_var - invalid key format
#############################################################################

subtest 'set_var: invalid key format' => sub {
    plan tests => 4;

    # Key with spaces - invalid
    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => 'invalid key', value => 'test' }
    );

    my $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result->[1]{error}, qr/invalid key format/i, "Error mentions invalid key format for spaces");

    # Key starting with hyphen - invalid
    $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => '-invalid', value => 'test' }
    );

    $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result->[1]{error}, qr/invalid key format/i, "Error mentions invalid key format for hyphen start");
};

#############################################################################
# Test: set_var - numeric key (valid for room topics etc.)
#############################################################################

subtest 'set_var: numeric key is valid' => sub {
    plan tests => 4;

    # Pure numeric key should be valid (used for room topics)
    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => '12345', value => 'room topic value' }
    );

    my $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    is($result->[1]{success}, 1, "Numeric key accepted successfully");

    # Numeric key starting with number followed by letters
    $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => '123abc', value => 'mixed value' }
    );

    $result = $api->set_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    is($result->[1]{success}, 1, "Key starting with number accepted successfully");
};

#############################################################################
# Test: set_var - node not found
#############################################################################

subtest 'set_var: node not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => 'test_key', value => 'test_value' }
    );

    my $result = $api->set_var($request, 999999999);
    is($result->[0], $api->HTTP_OK, "set_var returns HTTP 200");
    like($result->[1]{error}, qr/not found/i, "Error mentions node not found");
};

#############################################################################
# Test: set_var and get_vars - full cycle with test node
#############################################################################

# Create a temporary test setting node for full CRUD tests
my $test_node;
my $test_node_id;

subtest 'set_var: create and verify new key' => sub {
    # Create a test document node for our tests
    my $doc_type = $DB->getType('document');
    if ($doc_type) {
        $test_node_id = $DB->insertNode(
            "Test Node for NodeVars API " . time(),
            'document',
            $admin_user,
            { doctext => "Test content for nodevars tests" }
        );
        $test_node = $DB->getNodeById($test_node_id);
    }

    skip "Could not create test node", 6 unless $test_node;

    plan tests => 6;

    my $unique_key = 'test_nodevars_key_' . time();
    my $test_value = 'test_value_123';

    # Set a new var
    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { key => $unique_key, value => $test_value }
    );

    my $result = $api->set_var($request, $test_node_id);
    is($result->[0], $api->HTTP_OK, "set_var returns HTTP 200");
    is($result->[1]{success}, 1, "Success flag is set");
    is($result->[1]{key}, $unique_key, "Correct key returned");
    is($result->[1]{action}, 'set', "Action is 'set'");

    # Verify the var was set
    my $get_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user
    );

    my $get_result = $api->get_vars($get_request, $test_node_id);
    is($get_result->[1]{success}, 1, "get_vars succeeds");

    # Find our key in the vars array
    my ($found_var) = grep { $_->{key} eq $unique_key } @{$get_result->[1]{vars}};
    is($found_var->{value}, $test_value, "Correct value stored");
};

#############################################################################
# Test: delete_var - guest user denied
#############################################################################

subtest 'delete_var: guest user denied' => sub {
    plan tests => 1;

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        is_admin_flag => 0,
        postdata => { key => 'test_key' }
    );

    my $result = $api->delete_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "delete_var returns HTTP 401 for guest");
};

#############################################################################
# Test: delete_var - normal user denied
#############################################################################

subtest 'delete_var: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user,
        postdata => { key => 'test_key' }
    );

    my $result = $api->delete_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "delete_var returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: delete_var - missing key
#############################################################################

subtest 'delete_var: missing key' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => {}
    );

    my $result = $api->delete_var($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result->[1]{error}, qr/key.*required/i, "Error mentions key required");
};

#############################################################################
# Test: delete_var - key not found
#############################################################################

SKIP: {
    skip "No test node available", 1 unless $test_node;

    subtest 'delete_var: key not found' => sub {
        plan tests => 2;

        my $request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => { key => 'nonexistent_key_12345' }
        );

        my $result = $api->delete_var($request, $test_node_id);
        is($result->[0], $api->HTTP_OK, "delete_var returns HTTP 200");
        like($result->[1]{error}, qr/not found/i, "Error mentions key not found");
    };
}

#############################################################################
# Test: delete_var - success
#############################################################################

SKIP: {
    skip "No test node available", 1 unless $test_node;

    subtest 'delete_var: success' => sub {
        plan tests => 5;

        my $delete_key = 'test_delete_key_' . time();

        # First set a key
        my $set_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => { key => $delete_key, value => 'to_be_deleted' }
        );
        $api->set_var($set_request, $test_node_id);

        # Now delete it
        my $delete_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => { key => $delete_key }
        );

        my $result = $api->delete_var($delete_request, $test_node_id);
        is($result->[0], $api->HTTP_OK, "delete_var returns HTTP 200");
        is($result->[1]{success}, 1, "Success flag is set");
        is($result->[1]{key}, $delete_key, "Correct key returned");
        is($result->[1]{action}, 'deleted', "Action is 'deleted'");

        # Verify it's gone
        my $get_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user
        );
        my $get_result = $api->get_vars($get_request, $test_node_id);
        my ($found_var) = grep { $_->{key} eq $delete_key } @{$get_result->[1]{vars}};
        ok(!$found_var, "Key no longer exists after deletion");
    };
}

#############################################################################
# Test: bulk_update - guest user denied
#############################################################################

subtest 'bulk_update: guest user denied' => sub {
    plan tests => 1;

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        is_admin_flag => 0,
        postdata => { set => { key1 => 'value1' } }
    );

    my $result = $api->bulk_update($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_UNAUTHORIZED, "bulk_update returns HTTP 401 for guest");
};

#############################################################################
# Test: bulk_update - normal user denied
#############################################################################

subtest 'bulk_update: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user,
        postdata => { set => { key1 => 'value1' } }
    );

    my $result = $api->bulk_update($request, $test_setting->{node_id});
    is($result->[0], $api->HTTP_OK, "bulk_update returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: bulk_update - success with set and delete
#############################################################################

SKIP: {
    skip "No test node available", 1 unless $test_node;

    subtest 'bulk_update: set and delete operations' => sub {
        plan tests => 7;

        my $bulk_key1 = 'bulk_test_key1_' . time();
        my $bulk_key2 = 'bulk_test_key2_' . time();
        my $to_delete_key = 'bulk_delete_' . time();

        # First set a key to delete later
        my $setup_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => { key => $to_delete_key, value => 'will_be_deleted' }
        );
        $api->set_var($setup_request, $test_node_id);

        # Now bulk update
        my $request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => {
                set => {
                    $bulk_key1 => 'bulk_value1',
                    $bulk_key2 => 'bulk_value2'
                },
                delete => [$to_delete_key]
            }
        );

        my $result = $api->bulk_update($request, $test_node_id);
        is($result->[0], $api->HTTP_OK, "bulk_update returns HTTP 200");
        is($result->[1]{success}, 1, "Success flag is set");
        ok(scalar(grep { $_ eq $bulk_key1 } @{$result->[1]{updated}}) > 0, "bulk_key1 in updated list");
        ok(scalar(grep { $_ eq $bulk_key2 } @{$result->[1]{updated}}) > 0, "bulk_key2 in updated list");
        ok(scalar(grep { $_ eq $to_delete_key } @{$result->[1]{deleted}}) > 0, "to_delete_key in deleted list");

        # Verify state
        my $get_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user
        );
        my $get_result = $api->get_vars($get_request, $test_node_id);

        my ($found_key1) = grep { $_->{key} eq $bulk_key1 } @{$get_result->[1]{vars}};
        is($found_key1->{value}, 'bulk_value1', "bulk_key1 has correct value");

        my ($found_deleted) = grep { $_->{key} eq $to_delete_key } @{$get_result->[1]{vars}};
        ok(!$found_deleted, "to_delete_key was removed");
    };
}

#############################################################################
# Test: bulk_update - invalid key in set
#############################################################################

SKIP: {
    skip "No test node available", 1 unless $test_node;

    subtest 'bulk_update: invalid key produces error' => sub {
        plan tests => 3;

        # Keys starting with hyphen are invalid
        my $request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            postdata => {
                set => {
                    'valid_key' => 'value1',
                    '-invalid' => 'value2'  # Keys cannot start with hyphen
                }
            }
        );

        my $result = $api->bulk_update($request, $test_node_id);
        is($result->[0], $api->HTTP_OK, "bulk_update returns HTTP 200");
        is($result->[1]{success}, 1, "Success flag is set (partial success)");
        ok(scalar(@{$result->[1]{errors}}) > 0, "Errors array contains invalid key error");
    };
}

#############################################################################
# Cleanup
#############################################################################

if ($test_node && $test_node->{title} =~ /Test Node for NodeVars API/) {
    $DB->nukeNode($test_node, -1);
}

done_testing();

=head1 NAME

t/088_nodevars_api.t - Tests for Everything::API::nodevars

=head1 DESCRIPTION

Tests for the node vars API covering:
- Authorization checks (admins only)
- get_vars - retrieve all vars for a node
- set_var - set/update a var
- delete_var - delete a var
- bulk_update - bulk set and delete operations
- Input validation (missing fields, invalid key format)

=head1 AUTHOR

Everything2 Development Team

=cut
