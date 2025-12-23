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
use Everything::API::client_errors;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, 'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::client_errors->new();
ok($api, 'Created client_errors API instance');

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
is($routes->{'/'}, 'report_error', 'report_error route exists');

#############################################################################
# Test: Method not allowed (GET)
#############################################################################

subtest 'GET request returns method not allowed' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'GET'
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_UNIMPLEMENTED, 'Returns 405 for GET');
    is($result->[1]{error}, 'method_not_allowed', 'Error code is method_not_allowed');
};

#############################################################################
# Test: Invalid JSON
#############################################################################

subtest 'Invalid JSON returns error' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'POST',
        postdata => 'not valid json {'
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'Returns 400 for invalid JSON');
    is($result->[1]{error}, 'invalid_json', 'Error code is invalid_json');
};

#############################################################################
# Test: Missing message
#############################################################################

subtest 'Missing message returns error' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'POST',
        postdata => { error_type => 'test', message => '' }
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'Returns 400 for missing message');
    is($result->[1]{error}, 'message_required', 'Error code is message_required');
};

#############################################################################
# Test: Successful error report (logged-in user)
#############################################################################

subtest 'Successful error report from logged-in user' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'POST',
        postdata => {
            error_type => 'api_error',
            message => 'Test error from unit test',
            context => {
                url => 'http://localhost/test',
                action => 'unit testing'
            }
        }
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_OK, 'Returns 200 for valid error report');
    is($result->[1]{success}, 1, 'Success flag is set');
};

#############################################################################
# Test: Successful error report (guest user)
#############################################################################

subtest 'Successful error report from guest user' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user,
        request_method => 'POST',
        postdata => {
            error_type => 'js_error',
            message => 'Test error from guest',
            stack => 'Error: test\n    at TestFunction (test.js:1:1)'
        }
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_OK, 'Returns 200 for guest error report');
    is($result->[1]{success}, 1, 'Success flag is set for guest');
};

#############################################################################
# Test: Long message gets truncated (doesn't error)
#############################################################################

subtest 'Long message is handled gracefully' => sub {
    plan tests => 2;

    my $long_message = 'x' x 5000;  # 5000 chars, should be truncated to 2000
    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        request_method => 'POST',
        postdata => {
            error_type => 'test',
            message => $long_message
        }
    );

    my $result = $api->report_error($request);
    is($result->[0], $api->HTTP_OK, 'Returns 200 for long message');
    is($result->[1]{success}, 1, 'Success flag is set');
};

#############################################################################
# Test: All error types accepted
#############################################################################

subtest 'Different error types accepted' => sub {
    plan tests => 6;

    for my $error_type (qw(api_error js_error network_error)) {
        my $request = MockRequest->new(
            node_id => $normal_user->{node_id},
            title => $normal_user->{title},
            is_guest_flag => 0,
            nodedata => $normal_user,
            request_method => 'POST',
            postdata => {
                error_type => $error_type,
                message => "Test $error_type"
            }
        );

        my $result = $api->report_error($request);
        is($result->[0], $api->HTTP_OK, "Returns 200 for $error_type");
        is($result->[1]{success}, 1, "Success for $error_type");
    }
};

done_testing();

=head1 NAME

t/086_client_errors_api.t - Tests for Everything::API::client_errors

=head1 DESCRIPTION

Tests for the client-side error reporting API covering:
- Method validation (only POST allowed)
- Input validation (JSON format, required message)
- Guest user access (allowed - guests can report errors)
- Long message handling (truncation)
- Different error types

=head1 AUTHOR

Everything2 Development Team

=cut
