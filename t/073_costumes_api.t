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
use Everything::API::costumes;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

# Enable Halloween mode for testing costume purchases
# (The costume shop is only open during Halloween period)
$Everything::CONF->{force_halloween_mode} = 1;

my $api = Everything::API::costumes->new();
ok($api, "Created costumes API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Get an editor user for remove_costume tests
my $editor_user = $DB->getNode("genericdev", "user");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'buy'}, 'buy_costume', "buy route exists");
is($routes->{'remove'}, 'remove_costume', "remove route exists");

#############################################################################
# Test: buy_costume - guest denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    postdata => { costume => 'Test Costume' }
);

my $result = $api->buy_costume($guest_request);
is($result->[0], $api->HTTP_OK, "Guest gets HTTP 200");
is($result->[1]{success}, 0, "Guest request fails");
like($result->[1]{error}, qr/login/i, "Guest gets login required error");

#############################################################################
# Test: buy_costume - empty costume name
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { costume => '' }
);

$result = $api->buy_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Empty costume returns HTTP 200");
is($result->[1]{success}, 0, "Empty costume fails");
like($result->[1]{error}, qr/costume name/i, "Error mentions costume name");

#############################################################################
# Test: buy_costume - costume name too long
#############################################################################

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { costume => 'x' x 50 }  # Over 40 char limit
);

$result = $api->buy_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Long costume returns HTTP 200");
is($result->[1]{success}, 0, "Long costume fails");
like($result->[1]{error}, qr/40/i, "Error mentions 40 character limit");

#############################################################################
# Test: buy_costume - not enough GP
#############################################################################

# Save original GP
my $original_gp = $normal_user->{GP};
$normal_user->{GP} = 5;  # Less than 30 GP cost
$DB->updateNode($normal_user, -1);

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { costume => 'Test Costume' }
);

$result = $api->buy_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Low GP returns HTTP 200");
is($result->[1]{success}, 0, "Low GP fails");
like($result->[1]{error}, qr/GP/i, "Error mentions GP");

# Restore GP
$normal_user->{GP} = $original_gp;
$DB->updateNode($normal_user, -1);

#############################################################################
# Test: buy_costume - costume matches existing username
#############################################################################

$normal_user->{GP} = 100;
$DB->updateNode($normal_user, -1);

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    postdata => { costume => 'root' }  # Matches admin username
);

$result = $api->buy_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Username match returns HTTP 200");
is($result->[1]{success}, 0, "Username match fails");
like($result->[1]{error}, qr/username/i, "Error mentions username conflict");

#############################################################################
# Test: buy_costume - successful purchase
#############################################################################

$normal_user->{GP} = 100;
$DB->updateNode($normal_user, -1);

# Clear any existing costume
my $vars = $APP->getVars($normal_user);
delete $vars->{costume};
Everything::setVars($normal_user, $vars);
$DB->updateNode($normal_user, -1);

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user,
    vars => $vars,
    postdata => { costume => 'Spooky Ghost' }
);

$result = $api->buy_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Successful buy returns HTTP 200");
is($result->[1]{success}, 1, "Costume purchase succeeds");
like($result->[1]{message}, qr/Spooky Ghost/i, "Message includes costume name");
ok(defined $result->[1]{newCostume}, "Response includes newCostume");
is($result->[1]{newCostume}, 'Spooky Ghost', "newCostume matches requested costume");
ok(defined $result->[1]{newGP}, "Response includes newGP");
is($result->[1]{newGP}, 70, "GP was deducted (100 - 30 = 70)");

# Clean up costume
$vars = $APP->getVars($normal_user);
delete $vars->{costume};
Everything::setVars($normal_user, $vars);
$DB->updateNode($normal_user, -1);

#############################################################################
# Test: buy_costume - admin gets free costume
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { costume => 'Admin Ghost' }
);

my $admin_gp_before = $admin_user->{GP};
$result = $api->buy_costume($admin_request);
is($result->[0], $api->HTTP_OK, "Admin buy returns HTTP 200");
is($result->[1]{success}, 1, "Admin costume purchase succeeds");
is($result->[1]{newGP}, $admin_gp_before, "Admin GP was not deducted (free)");

# Clean up admin costume
$vars = $APP->getVars($admin_user);
delete $vars->{costume};
Everything::setVars($admin_user, $vars);
$DB->updateNode($admin_user, -1);

#############################################################################
# Test: remove_costume - guest denied
#############################################################################

$guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    postdata => { username => 'normaluser1' }
);

$result = $api->remove_costume($guest_request);
is($result->[0], $api->HTTP_OK, "Guest remove returns HTTP 200");
is($result->[1]{success}, 0, "Guest remove fails");
like($result->[1]{error}, qr/login/i, "Guest gets login required error");

#############################################################################
# Test: remove_costume - normal user denied (not editor)
#############################################################################

$normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    nodedata => $normal_user,
    postdata => { username => 'normaluser1' }
);

$result = $api->remove_costume($normal_request);
is($result->[0], $api->HTTP_OK, "Normal user remove returns HTTP 200");
is($result->[1]{success}, 0, "Normal user remove fails");
like($result->[1]{error}, qr/permission/i, "Normal user gets permission denied");

#############################################################################
# Test: remove_costume - missing username
#############################################################################

SKIP: {
    skip "No editor user available", 2 unless $editor_user;

    my $editor_request = MockRequest->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 1,
        nodedata => $editor_user,
        postdata => {}
    );

    $result = $api->remove_costume($editor_request);
    is($result->[0], $api->HTTP_OK, "Missing username returns HTTP 200");
    is($result->[1]{success}, 0, "Missing username fails");
}

#############################################################################
# Test: remove_costume - user not found
#############################################################################

SKIP: {
    skip "No editor user available", 2 unless $editor_user;

    my $editor_request = MockRequest->new(
        node_id => $editor_user->{node_id},
        title => $editor_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 1,
        nodedata => $editor_user,
        postdata => { username => 'nonexistent_user_xyz123' }
    );

    $result = $api->remove_costume($editor_request);
    is($result->[0], $api->HTTP_OK, "User not found returns HTTP 200");
    is($result->[1]{success}, 0, "User not found fails");
}

done_testing();

=head1 NAME

t/073_costumes_api.t - Tests for Everything::API::costumes

=head1 DESCRIPTION

Tests for the costumes API covering:
- buy_costume permission checks (guest denied)
- buy_costume input validation (empty name, too long, username conflict)
- buy_costume GP requirements
- buy_costume successful purchase
- buy_costume admin free costumes
- remove_costume permission checks (guest, non-editor denied)
- remove_costume input validation

Note: The test enables force_halloween_mode to allow costume purchases.

=head1 AUTHOR

Everything2 Development Team

=cut
