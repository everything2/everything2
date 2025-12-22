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
use Everything::API::easter_eggs;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::easter_eggs->new();
ok($api, "Created easter_eggs API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $target_user = $DB->getNode("normaluser2", "user");
ok($target_user, "Got target user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Store original easter_eggs count for cleanup
my $original_eggs = $APP->getVars($target_user)->{easter_eggs} || 0;

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{bestow}, 'bestow', "bestow route exists");

#############################################################################
# Test: bestow - guest user denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    is_admin_flag => 0,
    nodedata => $guest_user,
    request_method => 'POST'
);

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { users => [{ username => $target_user->{title} }] };
    };
}

my $result = $api->bestow($guest_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Guest bestow returns 403");
like($result->[1]{error}, qr/easter bunny/i, "Error has Easter Bunny reference");

#############################################################################
# Test: bestow - normal user denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 0,
    nodedata => $normal_user,
    request_method => 'POST'
);

$result = $api->bestow($normal_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Normal user bestow returns 403");
like($result->[1]{error}, qr/easter bunny/i, "Error has Easter Bunny reference");

#############################################################################
# Test: bestow - no users provided
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    request_method => 'POST'
);

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return {};  # No users
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "No users returns 400");
like($result->[1]{error}, qr/no users/i, "Error mentions no users");

#############################################################################
# Test: bestow - empty users array
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { users => [] };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Empty users returns 400");
like($result->[1]{error}, qr/no users/i, "Error mentions no users");

#############################################################################
# Test: bestow - non-existent user
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { users => [{ username => 'nonexistent_user_12345' }] };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_OK, "Non-existent user returns HTTP 200");
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");
is(scalar(@{$result->[1]{results}}), 1, "One result returned");
is($result->[1]{results}[0]{success}, 0, "Non-existent user fails");
like($result->[1]{results}[0]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: bestow - success with unified format
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { users => [{ username => $target_user->{title} }] };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_OK, "Bestow returns HTTP 200");
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");
is(scalar(@{$result->[1]{results}}), 1, "One result returned");
is($result->[1]{results}[0]{success}, 1, "Bestow succeeds");
is($result->[1]{results}[0]{amount}, 1, "Amount is 1");
ok($result->[1]{results}[0]{new_total} > $original_eggs, "New total is higher");
like($result->[1]{results}[0]{message}, qr/easter egg/i, "Message mentions easter egg");

#############################################################################
# Test: bestow - success with legacy format (usernames array)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { usernames => [$target_user->{title}] };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_OK, "Legacy format returns HTTP 200");
ok(ref($result->[1]{results}) eq 'ARRAY', "Results is an array");
is($result->[1]{results}[0]{success}, 1, "Legacy format succeeds");

#############################################################################
# Test: bestow - multiple users (mixed success/failure)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return {
            users => [
                { username => $target_user->{title} },
                { username => 'nonexistent_user_xyz' },
                { username => $normal_user->{title} }
            ]
        };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_OK, "Multiple users returns HTTP 200");
is(scalar(@{$result->[1]{results}}), 3, "Three results returned");

# First and third should succeed, second should fail
is($result->[1]{results}[0]{success}, 1, "First user succeeds");
is($result->[1]{results}[1]{success}, 0, "Second user (non-existent) fails");
is($result->[1]{results}[2]{success}, 1, "Third user succeeds");

#############################################################################
# Test: bestow - skips whitespace-only usernames
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::JSON_POSTDATA = sub {
        return { users => [{ username => '   ' }, { username => '' }] };
    };
}

$result = $api->bestow($admin_request);
is($result->[0], $api->HTTP_OK, "Whitespace usernames returns HTTP 200");
is(scalar(@{$result->[1]{results}}), 0, "No results for whitespace usernames");

#############################################################################
# Cleanup - restore original easter_eggs count
#############################################################################

# Use direct DB access for cleanup since setVars isn't available on $APP
my $updated_vars = $APP->getVars($target_user);
$updated_vars->{easter_eggs} = $original_eggs;
my $vars_string = join('&', map { "$_=$updated_vars->{$_}" } keys %$updated_vars);
$DB->sqlUpdate('setting', { vars => $vars_string },
    "setting_id = " . $target_user->{node_id});

# Also reset for normal_user if we gave them eggs
my $normal_vars = $APP->getVars($normal_user);
if ($normal_vars->{easter_eggs}) {
    $normal_vars->{easter_eggs} = 0;
    my $normal_vars_string = join('&', map { "$_=$normal_vars->{$_}" } keys %$normal_vars);
    $DB->sqlUpdate('setting', { vars => $normal_vars_string },
        "setting_id = " . $normal_user->{node_id});
}

done_testing();

=head1 NAME

t/079_easter_eggs_api.t - Tests for Everything::API::easter_eggs

=head1 DESCRIPTION

Tests for the easter_eggs API covering:
- Guest user denied
- Normal user denied (admin only)
- No users provided
- Empty users array
- Non-existent user handling
- Success with unified format
- Success with legacy format (usernames)
- Multiple users (mixed success/failure)
- Whitespace-only username handling

=head1 AUTHOR

Everything2 Development Team

=cut
