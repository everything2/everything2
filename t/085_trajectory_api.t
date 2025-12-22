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
use Everything::API::trajectory;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, 'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::trajectory->new();
ok($api, 'Created trajectory API instance');

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'Got normal user');

my $guest_user = $DB->getNode('guest user', 'user');
ok($guest_user, 'Got guest user');

#############################################################################
# Test: Routes check
#############################################################################

my $routes = $api->routes();
ok($routes, 'Routes defined');
is($routes->{'get_data'}, 'get_data', 'get_data route exists');

#############################################################################
# Test: Guest user denied
#############################################################################

subtest 'Authorization: guest users blocked' => sub {
    plan tests => 2;

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user
    );

    my $result = $api->get_data($guest_request);
    is($result->[0], $api->HTTP_FORBIDDEN, 'get_data returns 403 for guest');
    like($result->[1]{error}, qr/logged in/i, 'Error mentions login required');
};

#############################################################################
# Test: get_data - default parameters
#############################################################################

subtest 'get_data: default parameters' => sub {
    plan tests => 6;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => {}
    );

    my $result = $api->get_data($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    ok(exists $result->[1]{data}, 'Response has data array');
    is(ref($result->[1]{data}), 'ARRAY', 'data is an array');
    ok(exists $result->[1]{current_year}, 'Response has current_year');
    ok(exists $result->[1]{back_to_year}, 'Response has back_to_year');

    # Check that back_to_year is 5 years ago by default
    my $expected_back_year = (localtime)[5] + 1900 - 5;
    is($result->[1]{back_to_year}, $expected_back_year, 'Default back_to_year is 5 years ago');
};

#############################################################################
# Test: get_data - with custom back_to_year
#############################################################################

subtest 'get_data: custom back_to_year' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => { back_to_year => 2022 }
    );

    my $result = $api->get_data($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{back_to_year}, 2022, 'back_to_year matches request');
};

#############################################################################
# Test: get_data - minimum year is 1999
#############################################################################

subtest 'get_data: minimum year clamped to 1999' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => { back_to_year => 1990 }
    );

    my $result = $api->get_data($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{back_to_year}, 1999, 'back_to_year clamped to 1999');
};

#############################################################################
# Test: get_data - data structure validation
#############################################################################

subtest 'get_data: data structure validation' => sub {
    plan tests => 7;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        query_params => { back_to_year => 2024 }
    );

    my $result = $api->get_data($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');

    my $data = $result->[1]{data};
    ok(scalar(@$data) >= 1, 'Got at least one month of data');

    my $first_month = $data->[0];
    ok(exists $first_month->{year}, 'Month has year');
    ok(exists $first_month->{month}, 'Month has month');
    ok(exists $first_month->{writeup_count}, 'Month has writeup_count');
    ok(exists $first_month->{user_count}, 'Month has user_count');
    ok(exists $first_month->{cool_count}, 'Month has cool_count');
};

done_testing();

=head1 NAME

t/085_trajectory_api.t - Tests for Everything::API::trajectory

=head1 DESCRIPTION

Tests for the site trajectory API covering:
- Authorization (guest users blocked)
- Default parameters (5 years back)
- Custom back_to_year parameter
- Minimum year clamping (1999)
- Data structure validation

=head1 AUTHOR

Everything2 Development Team

=cut
