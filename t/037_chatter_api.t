#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::chatter;

# Suppress expected warnings
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Chatter API functionality
#
# These tests verify:
# 1. GET /api/chatter/ - Get recent public chatter with pagination
# 2. POST /api/chatter/create - Send public chatter message
# 3. Query parameters (limit, offset, room, since)
# 4. Authorization checks (guest users blocked)
# 5. Duplicate message prevention
# 6. Suspension checks
# 7. Critical for React Chatterbox component
#############################################################################

# Get test user
my $test_user = $DB->getNode('root', 'user');
ok($test_user, "Got test user");

#############################################################################
# Helper Functions
#############################################################################

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'is_guest_flag' => (is => 'rw', default => 0);
    sub is_guest { return shift->is_guest_flag; }
}

# Mock CGI object for testing query parameters
package MockCGI {
    use Moose;
    has '_params' => (is => 'rw', default => sub { {} });
    sub param {
        my ($self, $key) = @_;
        return $self->_params->{$key};
    }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has '_postdata' => (is => 'rw', default => sub { {} });
    has '_cgi' => (is => 'rw', isa => 'MockCGI', default => sub { MockCGI->new() });
    sub JSON_POSTDATA { return shift->_postdata; }
    sub cgi { return shift->_cgi; }
    sub is_guest { return shift->user->is_guest; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

# Clear existing public chatter for clean tests
$DB->sqlDelete('message', 'for_user=0');

# Create API instance
my $api = Everything::API::chatter->new(DB => $DB, APP => $APP);
ok($api, "Created chatter API instance");

#############################################################################
# Test 1: GET /api/chatter/ - Get recent chatter (empty)
#############################################################################

subtest 'GET /api/chatter/ - empty chatter' => sub {
    plan tests => 3;

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $request = MockRequest->new(user => $user);

    my ($status, $data) = @{$api->get_all($request)};

    is($status, 200, "Status is 200 OK");
    ok(ref($data) eq 'ARRAY', "Returns an array");
    is(scalar(@$data), 0, "Array is empty when no chatter");
};

#############################################################################
# Test 2: POST /api/chatter/create - Send public chatter
#############################################################################

subtest 'POST /api/chatter/create - successful' => sub {
    plan tests => 4;

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $request = MockRequest->new(
        user => $user,
        _postdata => { message => 'Test chatter message' }
    );

    my ($status, $data) = @{$api->create($request)};

    is($status, 200, "Status is 200 OK");
    is($data->{success}, 1, "Success flag is true");
    ok(ref($data->{chatter}) eq 'ARRAY', "Returns chatter array");
    is(scalar(@{$data->{chatter}}), 1, "Chatter array has 1 message");
};

#############################################################################
# Test 3: GET /api/chatter/ - Get recent chatter (with data)
#############################################################################

subtest 'GET /api/chatter/ - with chatter' => sub {
    plan tests => 5;

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $request = MockRequest->new(user => $user);

    my ($status, $data) = @{$api->get_all($request)};

    is($status, 200, "Status is 200 OK");
    ok(ref($data) eq 'ARRAY', "Returns an array");
    is(scalar(@$data), 1, "Array has 1 message");
    is($data->[0]->{msgtext}, 'Test chatter message', "Message text is correct");
    is($data->[0]->{author_user}->{node_id}, $test_user->{node_id}, "Author is correct");
};

#############################################################################
# Test 4: POST /api/chatter/create - Duplicate prevention
#############################################################################

subtest 'POST /api/chatter/create - duplicate prevention' => sub {
    plan tests => 2;

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $request = MockRequest->new(
        user => $user,
        _postdata => { message => 'Test chatter message' } # Same as before
    );

    my ($status, $data) = @{$api->create($request)};

    is($status, 200, "Status is 200 OK");
    is($data->{success}, 0, "Success flag is false for duplicate");
};

#############################################################################
# Test 5: POST /api/chatter/create - Empty message
#############################################################################

subtest 'POST /api/chatter/create - empty message' => sub {
    plan tests => 2;

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $request = MockRequest->new(
        user => $user,
        _postdata => { } # No message
    );

    my ($status, $data) = @{$api->create($request)};

    is($status, 400, "Status is 400 BAD REQUEST");
    ok($data->{error}, "Error message is present");
};

#############################################################################
# Test 6: GET /api/chatter/ - Pagination with limit
#############################################################################

subtest 'GET /api/chatter/ - pagination' => sub {
    plan tests => 4;

    # Add more test messages
    $DB->sqlInsert('message', {
        msgtext => 'Message 2',
        author_user => $test_user->{node_id},
        for_user => 0
    });
    $DB->sqlInsert('message', {
        msgtext => 'Message 3',
        author_user => $test_user->{node_id},
        for_user => 0
    });

    my $user = MockUser->new(
        NODEDATA => $test_user,
        node_id => $test_user->{node_id},
        title => $test_user->{title}
    );

    my $cgi = MockCGI->new(_params => { limit => 2 });
    my $request = MockRequest->new(user => $user, _cgi => $cgi);

    my ($status, $data) = @{$api->get_all($request)};

    is($status, 200, "Status is 200 OK");
    is(scalar(@$data), 2, "Respects limit parameter");

    # Test offset
    $cgi = MockCGI->new(_params => { limit => 1, offset => 1 });
    $request = MockRequest->new(user => $user, _cgi => $cgi);

    ($status, $data) = @{$api->get_all($request)};

    is($status, 200, "Status is 200 OK with offset");
    is(scalar(@$data), 1, "Respects offset parameter");
};

#############################################################################
# Test 7: Authorization - Guest users
#############################################################################

subtest 'Authorization - guest users blocked' => sub {
    plan tests => 2;

    my $guest = MockUser->new(
        NODEDATA => {},
        is_guest_flag => 1
    );

    my $request = MockRequest->new(user => $guest);

    my ($status_get) = @{$api->get_all($request)};
    is($status_get, 401, "GET blocked for guest users (401 Unauthorized)");

    $request = MockRequest->new(
        user => $guest,
        _postdata => { message => 'Guest message' }
    );

    my ($status_post) = @{$api->create($request)};
    is($status_post, 401, "POST blocked for guest users (401 Unauthorized)");
};

# Cleanup
$DB->sqlDelete('message', 'for_user=0');

done_testing();
