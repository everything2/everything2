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
use Everything::API::node_parameter;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::node_parameter->new();
ok($api, "Created node_parameter API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

# Get an editor user if available
my $editor_user = $DB->getNode("genericdev", "user");  # genericdev is in edev group
ok($editor_user, "Got editor user");

# Get a test node to work with
my $test_node = $DB->getNode("test page for node tests", "document");
unless ($test_node) {
    # Create a test node
    my $doc_type = $DB->getType('document');
    if ($doc_type) {
        my $test_node_id = $DB->insertNode(
            "Test Page for Node Parameter API " . time(),
            'document',
            $admin_user,
            { doctext => "Test content for node parameter tests" }
        );
        $test_node = $DB->getNodeById($test_node_id);
    }
}

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'get', "get route exists");
is($routes->{'set'}, 'set_param', "set_param route exists");
is($routes->{'delete'}, 'delete_param', "delete_param route exists");

#############################################################################
# Test: get - normal user denied
#############################################################################

subtest 'get: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get($request);
    is($result->[0], $api->HTTP_OK, "get returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: get - missing node_id
#############################################################################

subtest 'get: missing node_id' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user
    );

    my $result = $api->get($request);
    is($result->[0], $api->HTTP_OK, "get returns HTTP 200");
    like($result->[1]{error}, qr/node_id.*required/i, "Error mentions node_id required");
};

#############################################################################
# Test: get - node not found
#############################################################################

subtest 'get: node not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        query_params => { node_id => 999999999 }
    );

    my $result = $api->get($request);
    is($result->[0], $api->HTTP_OK, "get returns HTTP 200");
    like($result->[1]{error}, qr/no such node/i, "Error mentions no such node");
};

#############################################################################
# Test: get - success
#############################################################################

SKIP: {
    skip "No test node available", 1 unless $test_node;

    subtest 'get: success with valid node' => sub {
        plan tests => 5;

        my $request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user,
            query_params => { node_id => $test_node->{node_id} }
        );

        my $result = $api->get($request);
        is($result->[0], $api->HTTP_OK, "get returns HTTP 200");
        is($result->[1]{success}, 1, "Success flag is set");
        is($result->[1]{node}{node_id}, $test_node->{node_id}, "Correct node_id");
        ok(exists $result->[1]{available_parameters}, "Response has available_parameters");
        ok(exists $result->[1]{current_parameters}, "Response has current_parameters");
    };
}

#############################################################################
# Test: set_param - normal user denied
#############################################################################

subtest 'set_param: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user,
        postdata => {
            node_id => 123,
            param_name => 'test',
            param_value => 'value'
        }
    );

    my $result = $api->set_param($request);
    is($result->[0], $api->HTTP_OK, "set_param returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: set_param - missing required fields
#############################################################################

subtest 'set_param: missing required fields' => sub {
    plan tests => 6;

    # Missing node_id
    my $request1 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { param_name => 'test', param_value => 'value' }
    );
    my $result1 = $api->set_param($request1);
    is($result1->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result1->[1]{error}, qr/node_id.*required/i, "Error mentions node_id required");

    # Missing param_name
    my $request2 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { node_id => 123, param_value => 'value' }
    );
    my $result2 = $api->set_param($request2);
    is($result2->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result2->[1]{error}, qr/param_name.*required/i, "Error mentions param_name required");

    # Missing param_value
    my $request3 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { node_id => 123, param_name => 'test' }
    );
    my $result3 = $api->set_param($request3);
    is($result3->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result3->[1]{error}, qr/param_value.*required/i, "Error mentions param_value required");
};

#############################################################################
# Test: set_param - node not found
#############################################################################

subtest 'set_param: node not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => {
            node_id => 999999999,
            param_name => 'test',
            param_value => 'value'
        }
    );

    my $result = $api->set_param($request);
    is($result->[0], $api->HTTP_OK, "set_param returns HTTP 200");
    like($result->[1]{error}, qr/no such node/i, "Error mentions no such node");
};

#############################################################################
# Test: delete_param - normal user denied
#############################################################################

subtest 'delete_param: normal user denied' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 0,
        is_editor_flag => 0,
        nodedata => $normal_user,
        postdata => {
            node_id => 123,
            param_name => 'test'
        }
    );

    my $result = $api->delete_param($request);
    is($result->[0], $api->HTTP_OK, "delete_param returns HTTP 200");
    like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");
};

#############################################################################
# Test: delete_param - missing required fields
#############################################################################

subtest 'delete_param: missing required fields' => sub {
    plan tests => 4;

    # Missing node_id
    my $request1 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { param_name => 'test' }
    );
    my $result1 = $api->delete_param($request1);
    is($result1->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result1->[1]{error}, qr/node_id.*required/i, "Error mentions node_id required");

    # Missing param_name
    my $request2 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => { node_id => 123 }
    );
    my $result2 = $api->delete_param($request2);
    is($result2->[0], $api->HTTP_OK, "Returns HTTP 200");
    like($result2->[1]{error}, qr/param_name.*required/i, "Error mentions param_name required");
};

#############################################################################
# Test: delete_param - node not found
#############################################################################

subtest 'delete_param: node not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => {
            node_id => 999999999,
            param_name => 'test'
        }
    );

    my $result = $api->delete_param($request);
    is($result->[0], $api->HTTP_OK, "delete_param returns HTTP 200");
    like($result->[1]{error}, qr/no such node/i, "Error mentions no such node");
};

#############################################################################
# Test: Invalid JSON handling
#############################################################################

subtest 'Invalid JSON handling' => sub {
    plan tests => 4;

    # For set_param
    my $request1 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => 'not valid json {'
    );
    my $result1 = $api->set_param($request1);
    is($result1->[0], $api->HTTP_OK, "set_param returns HTTP 200");
    like($result1->[1]{error}, qr/invalid json/i, "Error mentions invalid JSON");

    # For delete_param
    my $request2 = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user,
        postdata => 'not valid json {'
    );
    my $result2 = $api->delete_param($request2);
    is($result2->[0], $api->HTTP_OK, "delete_param returns HTTP 200");
    like($result2->[1]{error}, qr/invalid json/i, "Error mentions invalid JSON");
};


#############################################################################
# Cleanup
#############################################################################

if ($test_node && $test_node->{title} =~ /Test Page for Node Parameter API/) {
    $DB->nukeNode($test_node, -1);
}

done_testing();

=head1 NAME

t/081_node_parameter_api.t - Tests for Everything::API::node_parameter

=head1 DESCRIPTION

Tests for the node parameter API covering:
- Authorization checks (editors and admins only)
- get - retrieve parameters for a node
- set_param - set/update a parameter
- delete_param - delete a parameter
- Input validation (missing fields, invalid JSON)

=head1 AUTHOR

Everything2 Development Team

=cut
