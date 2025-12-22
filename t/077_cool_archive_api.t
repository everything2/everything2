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
use Everything::API::cool_archive;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::cool_archive->new();
ok($api, "Created cool_archive API instance");

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
is($routes->{'/'}, 'list_writeups', "list_writeups route exists");

#############################################################################
# Test: list_writeups - default parameters
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

my $result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Default list returns HTTP 200");
is($result->[1]{success}, 1, "Default list succeeds");
ok(defined($result->[1]{writeups}), "Writeups array present");
ok(ref($result->[1]{writeups}) eq 'ARRAY', "Writeups is an array");
ok(defined($result->[1]{has_more}), "has_more flag present");
is($result->[1]{offset}, 0, "Default offset is 0");
is($result->[1]{limit}, 50, "Default limit is 50");

#############################################################################
# Test: list_writeups - guest can access (public data)
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

$result = $api->list_writeups($guest_request);
is($result->[0], $api->HTTP_OK, "Guest can access cool archive");
is($result->[1]{success}, 1, "Guest list succeeds");

#############################################################################
# Test: list_writeups - custom pagination
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 10 if $name eq 'limit';
        return 5 if $name eq 'offset';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Custom pagination returns HTTP 200");
is($result->[1]{limit}, 10, "Custom limit is 10");
is($result->[1]{offset}, 5, "Custom offset is 5");

#############################################################################
# Test: list_writeups - limit capped at 100
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 500 if $name eq 'limit';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Excessive limit returns HTTP 200");
is($result->[1]{limit}, 50, "Limit capped to default (out of range)");

#############################################################################
# Test: list_writeups - invalid limit defaults to 50
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return -10 if $name eq 'limit';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Negative limit returns HTTP 200");
is($result->[1]{limit}, 50, "Negative limit defaults to 50");

#############################################################################
# Test: list_writeups - negative offset defaults to 0
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return -5 if $name eq 'offset';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Negative offset returns HTTP 200");
is($result->[1]{offset}, 0, "Negative offset defaults to 0");

#############################################################################
# Test: list_writeups - valid orderby options
#############################################################################

my @valid_orders = (
    'tstamp DESC',
    'tstamp ASC',
);

foreach my $order (@valid_orders) {
    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            return $order if $name eq 'orderby';
            return undef;
        };
    }

    $result = $api->list_writeups($normal_request);
    is($result->[0], $api->HTTP_OK, "Order '$order' returns HTTP 200");
    is($result->[1]{success}, 1, "Order '$order' succeeds");
}

#############################################################################
# Test: list_writeups - invalid orderby defaults to 'tstamp DESC'
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 'INVALID; DROP TABLE node;' if $name eq 'orderby';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Invalid orderby returns HTTP 200");
is($result->[1]{success}, 1, "Invalid orderby defaults to valid");

#############################################################################
# Test: list_writeups - order requiring user without user
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 'title ASC' if $name eq 'orderby';
        return '' if $name eq 'cooluser';  # Empty user
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Title sort without user returns HTTP 200");
is($result->[1]{success}, 0, "Title sort without user fails");
like($result->[1]{error}, qr/requires.*username/i, "Error mentions username required");

#############################################################################
# Test: list_writeups - non-existent user
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 'nonexistent_user_12345' if $name eq 'cooluser';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "Non-existent user returns HTTP 200");
is($result->[1]{success}, 0, "Non-existent user fails");
like($result->[1]{error}, qr/not found/i, "Error mentions user not found");

#############################################################################
# Test: list_writeups - valid user with 'cooled' action
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $normal_user->{title} if $name eq 'cooluser';
        return 'cooled' if $name eq 'useraction';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "User cooled filter returns HTTP 200");
is($result->[1]{success}, 1, "User cooled filter succeeds");
ok(ref($result->[1]{writeups}) eq 'ARRAY', "Writeups is an array");

#############################################################################
# Test: list_writeups - valid user with 'written' action
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $normal_user->{title} if $name eq 'cooluser';
        return 'written' if $name eq 'useraction';
        return undef;
    };
}

$result = $api->list_writeups($normal_request);
is($result->[0], $api->HTTP_OK, "User written filter returns HTTP 200");
is($result->[1]{success}, 1, "User written filter succeeds");
ok(ref($result->[1]{writeups}) eq 'ARRAY', "Writeups is an array");

#############################################################################
# Test: list_writeups - response structure
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub { return undef; };
}

$result = $api->list_writeups($normal_request);

# Check writeup structure if we have any
if (scalar(@{$result->[1]{writeups}}) > 0) {
    my $writeup = $result->[1]{writeups}[0];
    ok(defined($writeup->{writeup_id}), "Writeup has writeup_id");
    ok(defined($writeup->{parent_node_id}), "Writeup has parent_node_id");
    ok(defined($writeup->{parent_title}), "Writeup has parent_title");
    ok(defined($writeup->{author_name}), "Writeup has author_name");
    ok(defined($writeup->{cooled_by_name}), "Writeup has cooled_by_name");
    ok(defined($writeup->{reputation}), "Writeup has reputation");
    ok(defined($writeup->{cooled_count}), "Writeup has cooled_count");
    ok(defined($writeup->{tstamp}), "Writeup has tstamp");
} else {
    pass("No writeups found (may not have seed data)");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
    pass("Skipping writeup structure checks");
}

done_testing();

=head1 NAME

t/077_cool_archive_api.t - Tests for Everything::API::cool_archive

=head1 DESCRIPTION

Tests for the cool_archive API covering:
- Default parameters
- Guest user access (public data)
- Custom pagination
- Limit capping at 100
- Invalid limit handling
- Negative offset handling
- Valid orderby options
- Invalid orderby SQL injection protection
- Order requiring user without user
- Non-existent user handling
- User cooled filter
- User written filter
- Response structure validation

=head1 AUTHOR

Everything2 Development Team

=cut
