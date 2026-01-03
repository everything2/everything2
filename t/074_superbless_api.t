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
use Everything::API::superbless;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::superbless->new();
ok($api, "Created superbless API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Get an editor user (genericeditor is in content editors group)
my $editor_user = $DB->getNode("genericeditor", "user");
ok($editor_user, "Got editor user");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'grant_gp'}, 'grant_gp', "grant_gp route exists");
is($routes->{'grant_xp'}, 'grant_xp', "grant_xp route exists");
is($routes->{'grant_cools'}, 'grant_cools', "grant_cools route exists");
is($routes->{'fiery_hug'}, 'fiery_hug', "fiery_hug route exists");

#############################################################################
# Test: grant_gp - guest denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    postdata => { users => [{ username => 'normaluser1', amount => 10 }] }
);

my $result = $api->grant_gp($guest_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Guest gets HTTP 403");
like($result->[1]{error}, qr/spell/i, "Guest gets permission denied");

#############################################################################
# Test: grant_gp - normal user denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { users => [{ username => 'normaluser1', amount => 10 }] }
);

$result = $api->grant_gp($normal_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Normal user gets HTTP 403");
like($result->[1]{error}, qr/spell/i, "Normal user gets permission denied");

#############################################################################
# Test: grant_gp - editor allowed
#############################################################################

# Save original GP
my $original_gp = $normal_user->{GP};

my $editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1', amount => 5 }] }
);

$result = $api->grant_gp($editor_request);
is($result->[0], $api->HTTP_OK, "Editor gets HTTP 200");
ok($result->[1]{results}, "Results array returned");
is(scalar @{$result->[1]{results}}, 1, "One result returned");
is($result->[1]{results}[0]{success}, 1, "GP grant succeeded");
is($result->[1]{results}[0]{amount}, 5, "Amount is correct");

# Revert GP
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, -5);

#############################################################################
# Test: grant_gp - no users provided
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [] }
);

$result = $api->grant_gp($editor_request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Empty users returns 400");
like($result->[1]{error}, qr/users/i, "Error mentions users");

#############################################################################
# Test: grant_gp - invalid amount
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1', amount => 'abc' }] }
);

$result = $api->grant_gp($editor_request);
is($result->[0], $api->HTTP_OK, "Invalid amount still returns 200 (partial)");
is($result->[1]{results}[0]{success}, 0, "Invalid amount entry fails");
like($result->[1]{results}[0]{error}, qr/Invalid/i, "Error mentions invalid");

#############################################################################
# Test: grant_gp - user not found
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'nonexistent_user_xyz123', amount => 10 }] }
);

$result = $api->grant_gp($editor_request);
is($result->[0], $api->HTTP_OK, "User not found still returns 200 (partial)");
is($result->[1]{results}[0]{success}, 0, "User not found entry fails");
like($result->[1]{results}[0]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: grant_xp - editor denied (admin only)
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1', amount => 100 }] }
);

$result = $api->grant_xp($editor_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Editor gets 403 for XP grant");
like($result->[1]{error}, qr/administrator/i, "XP grant needs admin");

#############################################################################
# Test: grant_xp - admin allowed
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'normaluser1', amount => 10 }] }
);

# Save original XP
$normal_user = $DB->getNode("normaluser1", "user");
my $original_xp = $normal_user->{experience};

$result = $api->grant_xp($admin_request);
is($result->[0], $api->HTTP_OK, "Admin gets HTTP 200 for XP grant");
ok($result->[1]{results}, "Results array returned");
is($result->[1]{results}[0]{success}, 1, "XP grant succeeded");
is($result->[1]{results}[0]{amount}, 10, "XP amount is correct");

# Revert XP
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustExp($normal_user, -10);

#############################################################################
# Test: grant_cools - editor denied (admin only)
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1', amount => 5 }] }
);

$result = $api->grant_cools($editor_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Editor gets 403 for cools grant");
like($result->[1]{error}, qr/administrator/i, "Cools grant needs admin");

#############################################################################
# Test: grant_cools - invalid amount (must be positive)
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'normaluser1', amount => -5 }] }
);

$result = $api->grant_cools($admin_request);
is($result->[0], $api->HTTP_OK, "Negative cools returns 200 (partial)");
is($result->[1]{results}[0]{success}, 0, "Negative cools entry fails");
like($result->[1]{results}[0]{error}, qr/positive/i, "Error mentions positive");

#############################################################################
# Test: fiery_hug - editor denied (admin only)
#############################################################################

$editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 1,
    nodedata => $editor_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

$result = $api->fiery_hug($editor_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Editor gets 403 for fiery hug");
like($result->[1]{error}, qr/bear|bobo/i, "Fiery hug denied with bear message");

#############################################################################
# Test: fiery_hug - admin allowed
#############################################################################

# Save original GP
$normal_user = $DB->getNode("normaluser1", "user");
$original_gp = $normal_user->{GP};

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'normaluser1' }] }
);

$result = $api->fiery_hug($admin_request);
is($result->[0], $api->HTTP_OK, "Admin gets HTTP 200 for fiery hug");
ok($result->[1]{results}, "Results array returned");
is($result->[1]{results}[0]{success}, 1, "Fiery hug succeeded");
is($result->[1]{results}[0]{amount}, -1, "Fiery hug removes 1 GP");

# Revert GP (add back the 1 that was removed)
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, 1);

#############################################################################
# Test: fiery_hug - user not found
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [{ username => 'nonexistent_user_xyz123' }] }
);

$result = $api->fiery_hug($admin_request);
is($result->[0], $api->HTTP_OK, "User not found returns 200 (partial)");
is($result->[1]{results}[0]{success}, 0, "User not found entry fails");
like($result->[1]{results}[0]{error}, qr/not found/i, "Error mentions not found");

#############################################################################
# Test: Multiple users in single request
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { users => [
        { username => 'normaluser1', amount => 1 },
        { username => 'nonexistent_xyz', amount => 1 },
        { username => 'root', amount => 1 }
    ]}
);

$result = $api->grant_gp($admin_request);
is($result->[0], $api->HTTP_OK, "Multiple users returns 200");
is(scalar @{$result->[1]{results}}, 3, "Three results returned");
is($result->[1]{results}[0]{success}, 1, "First user succeeded");
is($result->[1]{results}[1]{success}, 0, "Second user failed (not found)");
is($result->[1]{results}[2]{success}, 1, "Third user succeeded");

# Revert GP changes
$normal_user = $DB->getNode("normaluser1", "user");
$APP->adjustGP($normal_user, -1);
$admin_user = $DB->getNode("root", "user");
$APP->adjustGP($admin_user, -1);

done_testing();

=head1 NAME

t/074_superbless_api.t - Tests for Everything::API::superbless

=head1 DESCRIPTION

Tests for the superbless API covering:
- grant_gp permission checks (guest/normal denied, editor+ allowed)
- grant_gp input validation (no users, invalid amount, user not found)
- grant_xp permission checks (admin only)
- grant_cools permission checks (admin only, positive amounts only)
- fiery_hug permission checks (admin only)
- fiery_hug user not found handling
- Multiple users in single request (partial success)

=head1 AUTHOR

Everything2 Development Team

=cut
