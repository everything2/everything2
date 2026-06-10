#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::resurrect;
use MockRequest;

# Everything::API::resurrect -- POST /api/resurrect/node restores a deleted node from
# node heaven. Admin-only. This test pins the two authorization gates (guest -> 401 via
# the unauthorized_if_guest modifier; non-admin -> permission-denied) without performing
# an actual resurrection (which mutates the node table).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::resurrect->new();
ok($api, 'Created resurrect API instance');

is_deeply($api->routes, { 'node' => 'resurrect_node' }, 'routes: node -> resurrect_node');

#############################################################################
# Guest -> 401 (the unauthorized_if_guest 'around' fires before the body)
#############################################################################

my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->resurrect_node($guest);
is($r->[0], $api->HTTP_UNAUTHORIZED, 'guest is unauthorized (401)');

#############################################################################
# Logged-in non-admin -> permission denied (isAdmin check in the body)
#############################################################################

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'got normaluser1');
ok(!$APP->isAdmin($normal_user), 'normaluser1 is not an admin (precondition)');

my $normal = MockRequest->new(
    node_id       => $normal_user->{node_id},
    title         => $normal_user->{title},
    is_guest_flag => 0,
    nodedata      => $normal_user,
    postdata      => { node_id => 2 },
);
$r = $api->resurrect_node($normal);
is($r->[0], $api->HTTP_OK, 'non-admin returns HTTP 200 (E2 convention)');
is($r->[1]{success}, 0, 'non-admin cannot resurrect');
like($r->[1]{error}, qr/permission denied|admin/i, 'permission-denied error returned');

done_testing();

=head1 NAME

t/136_resurrect_api.t - Tests for Everything::API::resurrect (authorization gates)

=cut
