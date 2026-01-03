#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::teddybear;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::teddybear->new();
ok($api, "Created teddybear API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

my $editor_user = $DB->getNode("genericeditor", "user");
ok($editor_user, "Got editor user");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'hug'}, 'hug', "hug route exists");

#############################################################################
# Test: hug - guest denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

my $result = $api->hug($guest_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Guest gets HTTP 403");
like($result->[1]{error}, qr/bear|bobo/i, "Guest gets bear message");

#############################################################################
# Test: hug - normal user denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

$result = $api->hug($normal_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Normal user gets HTTP 403");
like($result->[1]{error}, qr/bear|bobo/i, "Normal user gets bear message");

#############################################################################
# Test: hug - editor denied (admin only)
#############################################################################

my $editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

$result = $api->hug($editor_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Editor gets HTTP 403");
like($result->[1]{error}, qr/bear|bobo/i, "Editor gets bear message");

#############################################################################
# Test: hug - admin allowed
#############################################################################

# Save original GP
my $original_gp = $normal_user->{GP};

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

$result = $api->hug($admin_request);
is($result->[0], $api->HTTP_OK, "Admin gets HTTP 200");
ok($result->[1]{success}, "Success flag set");
ok($result->[1]{results}, "Results array returned");
is(scalar @{$result->[1]{results}}, 1, "One result returned");
is($result->[1]{results}[0]{success}, 1, "Hug succeeded");
is($result->[1]{results}[0]{amount}, 2, "Hug grants 2 GP");
like($result->[1]{results}[0]{message}, qr/2 GP/i, "Message mentions 2 GP");

# Revert GP
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, -2);

#############################################################################
# Test: hug - no users provided
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [] }
);

$result = $api->hug($admin_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Empty users returns 400");
like($result->[1]{error}, qr/users/i, "Error mentions users");

#############################################################################
# Test: hug - user not found
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'nonexistent_user_xyz123' }] }
);

$result = $api->hug($admin_request);
is($result->[0], $api->HTTP_OK, "User not found returns 200 (partial)");
is($result->[1]{results}[0]{success}, 0, "User not found entry fails");
like($result->[1]{results}[0]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: hug - legacy format (usernames array)
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { usernames => ['normaluser1'] }  # Legacy format
);

$result = $api->hug($admin_request);
is($result->[0], $api->HTTP_OK, "Legacy format returns 200");
is($result->[1]{results}[0]{success}, 1, "Legacy format hug succeeds");

# Revert GP
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, -2);

#############################################################################
# Test: hug - multiple users
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [
        { username => 'normaluser1' },
        { username => 'nonexistent_xyz' },
        { username => 'root' }
    ]}
);

$result = $api->hug($admin_request);
is($result->[0], $api->HTTP_OK, "Multiple users returns 200");
is(scalar @{$result->[1]{results}}, 3, "Three results returned");
is($result->[1]{results}[0]{success}, 1, "First user succeeded");
is($result->[1]{results}[1]{success}, 0, "Second user failed (not found)");
is($result->[1]{results}[2]{success}, 1, "Third user succeeded");

# Revert GP changes
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, -2);
$admin_user = $DB->getNode("root", "user");
$APP->adjustGP($admin_user, -2);

done_testing();

=head1 NAME

t/075_teddybear_api.t - Tests for Everything::API::teddybear

=head1 DESCRIPTION

Tests for the teddybear API (Giant Teddy Bear Suit) covering:
- hug permission checks (only admins allowed)
- hug grants exactly 2 GP per user
- hug no users provided error
- hug user not found handling
- hug legacy format (usernames array) support
- Multiple users in single request (partial success)

Note: The Giant Teddy Bear posts a public hug message to the chatterbox.
This is in contrast to the Fiery Teddy Bear (superbless/fiery_hug) which
removes 1 GP instead of granting 2 GP.

=head1 AUTHOR

Everything2 Development Team

=cut
