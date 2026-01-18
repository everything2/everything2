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
use Everything::API::usergrouppicks;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::usergrouppicks->new();
ok($api, "Created usergrouppicks API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'unlink'}, 'unlink_node', "unlink route exists");

#############################################################################
# Test: unlink_node - guest denied
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user,
    postdata => { weblog_id => 123, node_id => 456 }
);

my $result = $api->unlink_node($guest_request);
is($result->[0], $api->HTTP_OK, "Guest gets HTTP 200");
is($result->[1]{success}, 0, "Guest request fails");
like($result->[1]{error}, qr/login/i, "Guest gets login required error");

#############################################################################
# Test: unlink_node - normal user denied
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 0,
    nodedata => $normal_user,
    postdata => { weblog_id => 123, node_id => 456 }
);

$result = $api->unlink_node($normal_request);
is($result->[0], $api->HTTP_OK, "Normal user gets HTTP 200");
is($result->[1]{success}, 0, "Normal user request fails");
like($result->[1]{error}, qr/admin/i, "Normal user gets admin required error");

#############################################################################
# Test: unlink_node - missing weblog_id
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { node_id => 456 }
);

$result = $api->unlink_node($admin_request);
is($result->[0], $api->HTTP_OK, "Missing weblog_id returns HTTP 200");
is($result->[1]{success}, 0, "Missing weblog_id fails");
like($result->[1]{error}, qr/weblog_id/i, "Error mentions weblog_id");

#############################################################################
# Test: unlink_node - missing node_id
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { weblog_id => 123 }
);

$result = $api->unlink_node($admin_request);
is($result->[0], $api->HTTP_OK, "Missing node_id returns HTTP 200");
is($result->[1]{success}, 0, "Missing node_id fails");
like($result->[1]{error}, qr/node_id/i, "Error mentions node_id");

#############################################################################
# Test: unlink_node - invalid weblog_id (non-numeric)
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { weblog_id => 'abc', node_id => 456 }
);

$result = $api->unlink_node($admin_request);
is($result->[0], $api->HTTP_OK, "Invalid weblog_id returns HTTP 200");
is($result->[1]{success}, 0, "Invalid weblog_id fails");

#############################################################################
# Test: unlink_node - invalid node_id (non-numeric)
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { weblog_id => 123, node_id => 'xyz' }
);

$result = $api->unlink_node($admin_request);
is($result->[0], $api->HTTP_OK, "Invalid node_id returns HTTP 200");
is($result->[1]{success}, 0, "Invalid node_id fails");

#############################################################################
# Test: unlink_node - admin success (with non-existent IDs - should still succeed)
#############################################################################

$admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user,
    postdata => { weblog_id => 999999, node_id => 999999 }
);

$result = $api->unlink_node($admin_request);
is($result->[0], $api->HTTP_OK, "Admin unlink returns HTTP 200");
is($result->[1]{success}, 1, "Admin unlink succeeds");
like($result->[1]{message}, qr/unlinked/i, "Success message mentions unlinked");

done_testing();

=head1 NAME

t/072_usergrouppicks_api.t - Tests for Everything::API::usergrouppicks

=head1 DESCRIPTION

Tests for the usergroup picks API covering:
- unlink_node permission checks (guest, normal, admin)
- unlink_node input validation
- unlink_node functionality

=head1 AUTHOR

Everything2 Development Team

=cut
