#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib '/var/libraries/lib/perl5';
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::nodelets;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, 'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::nodelets->new();
ok($api, 'Created nodelets API instance');

#############################################################################
# Test Setup: Get test users and nodelets
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'Got normal user');

my $guest_user = $DB->getNode('guest user', 'user');
ok($guest_user, 'Got guest user');

# Get some actual nodelets from the database
my $nodelet_type = $DB->getType('nodelet');
my $nodelet_ids = $DB->selectNodeWhere({}, $nodelet_type, 'node_id', 3) || [];
my @nodelets;
foreach my $id (@$nodelet_ids) {
    push @nodelets, $DB->getNodeById($id);
}
ok(scalar(@nodelets) >= 2, 'Found at least 2 nodelets in database');

my $nodelet1 = $nodelets[0];
my $nodelet2 = $nodelets[1];

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, 'Routes defined');
is($routes->{'/'}, 'get_or_update', 'get_or_update route exists');

#############################################################################
# Test: Guest user denied
#############################################################################

subtest 'Authorization: guest users blocked' => sub {
    plan tests => 2;

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user,
        request_method => 'GET'
    );

    my $result = $api->get_or_update($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, 'GET returns 401 for guest');

    $guest_request->{request_method} = 'POST';
    $result = $api->get_or_update($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, 'POST returns 401 for guest');
};

#############################################################################
# Test: get_nodelets - empty nodelets
#############################################################################

subtest 'get_nodelets: empty nodelet list' => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        vars => { nodelets => '' },
        request_method => 'GET'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_OK, 'GET returns HTTP 200');
    is($result->[1]{success}, 1, 'Success flag is set');
    is(ref($result->[1]{nodelets}), 'ARRAY', 'nodelets is an array');
};

#############################################################################
# Test: get_nodelets - with nodelets
#############################################################################

SKIP: {
    skip 'Need at least 2 nodelets', 1 unless $nodelet1 && $nodelet2;

    subtest 'get_nodelets: with nodelet IDs' => sub {
        plan tests => 5;

        my $nodelet_str = $nodelet1->{node_id} . ',' . $nodelet2->{node_id};
        my $request = MockRequest->new(
            node_id => $normal_user->{node_id},
            title => $normal_user->{title},
            is_guest_flag => 0,
            nodedata => $normal_user,
            vars => { nodelets => $nodelet_str },
            request_method => 'GET'
        );

        my $result = $api->get_or_update($request);
        is($result->[0], $api->HTTP_OK, 'GET returns HTTP 200');
        is($result->[1]{success}, 1, 'Success flag is set');
        is(scalar(@{$result->[1]{nodelets}}), 2, 'Got 2 nodelets');
        is($result->[1]{nodelets}[0]{node_id}, $nodelet1->{node_id}, 'First nodelet ID matches');
        is($result->[1]{nodelets}[1]{node_id}, $nodelet2->{node_id}, 'Second nodelet ID matches');
    };
}

#############################################################################
# Test: get_nodelets - handles invalid IDs gracefully
#############################################################################

subtest 'get_nodelets: handles invalid IDs' => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        vars => { nodelets => '999999999,abc,' . ($nodelet1 ? $nodelet1->{node_id} : '') },
        request_method => 'GET'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_OK, 'GET returns HTTP 200');
    is($result->[1]{success}, 1, 'Success flag is set');
    # Only valid, existing nodelet should be in result
    ok(scalar(@{$result->[1]{nodelets}}) <= 1, 'Invalid IDs filtered out');
};

#############################################################################
# Test: update_nodelets - invalid JSON
#############################################################################

subtest 'update_nodelets: invalid JSON' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => 'not valid json {',
        request_method => 'POST'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'POST returns 400 for invalid JSON');
    is($result->[1]{error}, 'invalid_json', 'Error code is invalid_json');
};

#############################################################################
# Test: update_nodelets - missing nodelet_ids
#############################################################################

subtest 'update_nodelets: missing nodelet_ids' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { some_other_field => 'value' },
        request_method => 'POST'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'POST returns 400 for missing nodelet_ids');
    is($result->[1]{error}, 'invalid_nodelet_ids', 'Error code is invalid_nodelet_ids');
};

#############################################################################
# Test: update_nodelets - nodelet_ids not array
#############################################################################

subtest 'update_nodelets: nodelet_ids not array' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { nodelet_ids => 'not_an_array' },
        request_method => 'POST'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'POST returns 400 for non-array nodelet_ids');
    is($result->[1]{error}, 'invalid_nodelet_ids', 'Error code is invalid_nodelet_ids');
};

#############################################################################
# Test: update_nodelets - invalid nodelet ID format
#############################################################################

subtest 'update_nodelets: invalid nodelet ID format' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { nodelet_ids => ['abc', 123] },
        request_method => 'POST'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'POST returns 400 for non-numeric ID');
    is($result->[1]{error}, 'invalid_nodelet_id', 'Error code is invalid_nodelet_id');
};

#############################################################################
# Test: update_nodelets - nodelet not found
#############################################################################

subtest 'update_nodelets: nodelet not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { nodelet_ids => [999999999] },
        request_method => 'POST'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_NOT_FOUND, 'POST returns 404 for nonexistent nodelet');
    is($result->[1]{error}, 'nodelet_not_found', 'Error code is nodelet_not_found');
};

#############################################################################
# Test: update_nodelets - success (but won't persist due to MockUser)
#############################################################################

SKIP: {
    skip 'Need at least 2 nodelets', 1 unless $nodelet1 && $nodelet2;

    subtest 'update_nodelets: success response' => sub {
        plan tests => 2;

        my $request = MockRequest->new(
            node_id => $normal_user->{node_id},
            title => $normal_user->{title},
            is_guest_flag => 0,
            nodedata => $normal_user,
            postdata => { nodelet_ids => [$nodelet1->{node_id}, $nodelet2->{node_id}] },
            request_method => 'POST'
        );

        my $result = $api->get_or_update($request);
        is($result->[0], $api->HTTP_OK, 'POST returns 200 for valid nodelets');
        is($result->[1]{success}, 1, 'Success flag is set');
    };
}

#############################################################################
# Test: Method not allowed
#############################################################################

subtest 'Method not allowed for PUT/DELETE' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'PUT'
    );

    my $result = $api->get_or_update($request);
    is($result->[0], $api->HTTP_UNIMPLEMENTED, 'PUT returns 405');
    is($result->[1]{error}, 'method_not_allowed', 'Error code is method_not_allowed');
};

done_testing();

=head1 NAME

t/082_nodelets_api.t - Tests for Everything::API::nodelets

=head1 DESCRIPTION

Tests for the nodelets API covering:
- Authorization (guest users blocked)
- get_nodelets - retrieve user's nodelet configuration
- update_nodelets - update nodelet order
- Input validation (invalid JSON, missing fields, bad IDs)
- HTTP method handling

=head1 AUTHOR

Everything2 Development Team

=cut
