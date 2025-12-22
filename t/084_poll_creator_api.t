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
use Everything::API::poll_creator;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, 'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::poll_creator->new();
ok($api, 'Created poll_creator API instance');

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
is($routes->{'/create'}, 'create_poll', 'create_poll route exists');

#############################################################################
# Test: Guest user denied
#############################################################################

subtest 'Authorization: guest users blocked' => sub {
    plan tests => 1;

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user,
        postdata => { title => 'Test Poll', question => 'Test?', options => ['A', 'B'] }
    );

    my $result = $api->create_poll($guest_request);
    is($result->[0], $api->HTTP_UNAUTHORIZED, 'create_poll returns 401 for guest');
};

#############################################################################
# Test: Invalid JSON
#############################################################################

subtest 'create_poll: invalid JSON' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => 'not valid json {'
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{error}, 'invalid_json', 'Error is invalid_json');
};

#############################################################################
# Test: Missing title
#############################################################################

subtest 'create_poll: missing title' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => '', question => 'Test?', options => ['A', 'B'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/title.*required/i, 'Error mentions title required');
};

#############################################################################
# Test: Missing question
#############################################################################

subtest 'create_poll: missing question' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => 'Test Poll', question => '', options => ['A', 'B'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/question.*required/i, 'Error mentions question required');
};

#############################################################################
# Test: Not enough options
#############################################################################

subtest 'create_poll: not enough options' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => 'Test Poll', question => 'Test?', options => ['A'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/at least 2/i, 'Error mentions at least 2 options required');
};

#############################################################################
# Test: Title too long
#############################################################################

subtest 'create_poll: title too long' => sub {
    plan tests => 2;

    my $long_title = 'x' x 100;  # 100 chars, max is 64
    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => $long_title, question => 'Test?', options => ['A', 'B'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/64 characters/i, 'Error mentions 64 character limit');
};

#############################################################################
# Test: Question too long
#############################################################################

subtest 'create_poll: question too long' => sub {
    plan tests => 2;

    my $long_question = 'x' x 300;  # 300 chars, max is 255
    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => 'Test Poll', question => $long_question, options => ['A', 'B'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/255 characters/i, 'Error mentions 255 character limit');
};

#############################################################################
# Test: Option too long
#############################################################################

subtest 'create_poll: option too long' => sub {
    plan tests => 2;

    my $long_option = 'x' x 300;  # 300 chars, max is 255
    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => { title => 'Test Poll', question => 'Test?', options => [$long_option, 'B'] }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/255 characters/i, 'Error mentions 255 character limit');
};

#############################################################################
# Test: Successful poll creation
#############################################################################

my $test_poll_title = 'API Test Poll ' . time();

subtest 'create_poll: success' => sub {
    plan tests => 5;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            title => $test_poll_title,
            question => 'What is your favorite color?',
            options => ['Red', 'Blue', 'Green']
        }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    is($result->[1]{success}, 1, 'Success flag is set');
    ok($result->[1]{poll_id}, 'Poll ID returned');
    like($result->[1]{poll_title}, qr/API Test Poll/, 'Poll title matches');
    like($result->[1]{message}, qr/created successfully/i, 'Success message returned');
};

#############################################################################
# Test: Duplicate title rejected
#############################################################################

subtest 'create_poll: duplicate title rejected' => sub {
    plan tests => 2;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user,
        postdata => {
            title => $test_poll_title,
            question => 'Another question?',
            options => ['Yes', 'No']
        }
    );

    my $result = $api->create_poll($request);
    is($result->[0], $api->HTTP_OK, 'Returns HTTP 200');
    like($result->[1]{error}, qr/already exists/i, 'Error mentions poll already exists');
};

#############################################################################
# Cleanup: Remove test poll
#############################################################################

my $test_poll = $DB->getNode($test_poll_title, 'e2poll');
if ($test_poll) {
    $DB->nukeNode($test_poll, -1);
}

done_testing();

=head1 NAME

t/084_poll_creator_api.t - Tests for Everything::API::poll_creator

=head1 DESCRIPTION

Tests for the poll creation API covering:
- Authorization (guest users blocked)
- Input validation (title, question, options)
- Length limits
- Duplicate title detection
- Successful poll creation

=head1 AUTHOR

Everything2 Development Team

=cut
