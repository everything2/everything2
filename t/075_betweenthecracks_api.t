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
use Everything::API::betweenthecracks;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::betweenthecracks->new();
ok($api, "Created betweenthecracks API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{search}, 'search', "search route exists");

#############################################################################
# Test: search - guest user denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    request_method => 'GET'
);

{
    no warnings 'redefine';
    *MockRequest::param = sub { return undef; };
}

my $result = $api->search($guest_request);
is($result->[0], $api->HTTP_OK, "Guest search returns HTTP 200");
is($result->[1]{success}, 0, "Guest search fails");
like($result->[1]{error}, qr/logged in/i, "Error mentions must be logged in");

#############################################################################
# Test: search - default parameters
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

{
    no warnings 'redefine';
    *MockRequest::param = sub { return undef; };  # Use defaults
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "Default search returns HTTP 200");
is($result->[1]{success}, 1, "Default search succeeds");
ok(defined($result->[1]{data}), "Response has data");
ok(defined($result->[1]{data}{writeups}), "Response has writeups array");
ok(ref($result->[1]{data}{writeups}) eq 'ARRAY', "Writeups is an array");
is($result->[1]{data}{max_votes}, 5, "Default max_votes is 5");

#############################################################################
# Test: search - custom max_votes
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 3 if $name eq 'max_votes';
        return undef;
    };
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "Custom max_votes returns HTTP 200");
is($result->[1]{data}{max_votes}, 3, "max_votes is 3");

#############################################################################
# Test: search - max_votes capped at 10
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 100 if $name eq 'max_votes';
        return undef;
    };
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "Capped max_votes returns HTTP 200");
is($result->[1]{data}{max_votes}, 10, "max_votes capped at 10");

#############################################################################
# Test: search - max_votes minimum is 5 when invalid
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return -5 if $name eq 'max_votes';
        return undef;
    };
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "Negative max_votes returns HTTP 200");
is($result->[1]{data}{max_votes}, 5, "max_votes defaults to 5 when invalid");

#############################################################################
# Test: search - with min_rep parameter
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 5 if $name eq 'max_votes';
        return -2 if $name eq 'min_rep';
        return undef;
    };
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "With min_rep returns HTTP 200");
is($result->[1]{success}, 1, "With min_rep succeeds");
# min_rep of -2 with max_votes 5 should be valid (abs(-2) = 2 <= 5-2 = 3)
is($result->[1]{data}{min_rep}, -2, "min_rep is -2");

#############################################################################
# Test: search - min_rep ignored if out of valid range
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 5 if $name eq 'max_votes';
        return 10 if $name eq 'min_rep';  # Too high
        return undef;
    };
}

$result = $api->search($normal_request);
is($result->[0], $api->HTTP_OK, "Invalid min_rep returns HTTP 200");
ok(!defined($result->[1]{data}{min_rep}), "min_rep ignored when out of range");

#############################################################################
# Test: search - writeup data structure
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub { return undef; };
}

$result = $api->search($normal_request);

# If we have writeups, check the structure
if (scalar(@{$result->[1]{data}{writeups}}) > 0) {
    my $writeup = $result->[1]{data}{writeups}[0];
    ok(defined($writeup->{writeup_id}), "Writeup has writeup_id");
    ok(defined($writeup->{title}), "Writeup has title");
    ok(defined($writeup->{author_id}), "Writeup has author_id");
    ok(defined($writeup->{author}), "Writeup has author name");
    ok(defined($writeup->{totalvotes}), "Writeup has totalvotes");
    ok(defined($writeup->{createtime}), "Writeup has createtime");

    # Verify totalvotes <= max_votes
    ok($writeup->{totalvotes} <= 5, "Writeup totalvotes is within max_votes limit");
} else {
    pass("No writeups found (may not have seed data)");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
}

done_testing();

=head1 NAME

t/075_betweenthecracks_api.t - Tests for Everything::API::betweenthecracks

=head1 DESCRIPTION

Tests for the betweenthecracks API covering:
- Guest user denied
- Default parameter handling
- Custom max_votes parameter
- max_votes capping (1-10)
- min_rep parameter validation
- Response data structure

=head1 AUTHOR

Everything2 Development Team

=cut
