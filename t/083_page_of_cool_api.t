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
use Everything::API::page_of_cool;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, 'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::page_of_cool->new();
ok($api, 'Created page_of_cool API instance');

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'Got normal user');

my $admin_user = $DB->getNode('root', 'user');
ok($admin_user, 'Got admin user');

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, 'Routes defined');
is($routes->{'/coolnodes'}, 'list_coolnodes', 'list_coolnodes route exists');
is($routes->{'/endorsements/:editor_id'}, 'get_endorsements', 'get_endorsements route exists');

#############################################################################
# Test: list_coolnodes - basic response
#############################################################################

subtest 'list_coolnodes: basic response' => sub {
    plan tests => 5;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => {}
    );

    my $result = $api->list_coolnodes($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    ok(exists $result->[1]{coolnodes}, 'Response has coolnodes array');
    is(ref($result->[1]{coolnodes}), 'ARRAY', 'coolnodes is an array');
    ok(exists $result->[1]{pagination}, 'Response has pagination');
    ok(exists $result->[1]{pagination}{total}, 'Pagination has total');
};

#############################################################################
# Test: list_coolnodes - with pagination
#############################################################################

subtest 'list_coolnodes: pagination params' => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => { limit => 10, offset => 5 }
    );

    my $result = $api->list_coolnodes($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{pagination}{limit}, 10, 'Limit is applied');
    is($result->[1]{pagination}{offset}, 5, 'Offset is applied');
};

#############################################################################
# Test: list_coolnodes - limit clamped to 100
#############################################################################

subtest 'list_coolnodes: limit clamped to max' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => { limit => 500 }
    );

    my $result = $api->list_coolnodes($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{pagination}{limit}, 50, 'Limit clamped to 50 (> 100 defaults to 50)');
};

#############################################################################
# Test: get_endorsements - invalid editor_id
#############################################################################

subtest 'get_endorsements: invalid editor_id' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_endorsements($request, 0);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{error}, 'invalid_editor_id', 'Error code is invalid_editor_id');
};

#############################################################################
# Test: get_endorsements - editor not found
#############################################################################

subtest 'get_endorsements: editor not found' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_endorsements($request, 999999999);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{error}, 'editor_not_found', 'Error code is editor_not_found');
};

#############################################################################
# Test: get_endorsements - valid editor
#############################################################################

subtest 'get_endorsements: valid editor' => sub {
    plan tests => 6;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    my $result = $api->get_endorsements($request, $admin_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{success}, 1, 'Success flag is set');
    is($result->[1]{editor_id}, $admin_user->{node_id}, 'Correct editor_id returned');
    is($result->[1]{editor_name}, $admin_user->{title}, 'Correct editor_name returned');
    ok(exists $result->[1]{count}, 'Response has count');
    is(ref($result->[1]{nodes}), 'ARRAY', 'nodes is an array');
};

done_testing();

=head1 NAME

t/083_page_of_cool_api.t - Tests for Everything::API::page_of_cool

=head1 DESCRIPTION

Tests for the Page of Cool API covering:
- list_coolnodes - paginated list of recently cooled nodes
- get_endorsements - nodes endorsed by a specific editor
- Pagination parameters and limits
- Error handling for invalid inputs

=head1 AUTHOR

Everything2 Development Team

=cut
