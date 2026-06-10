#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::weblogmenu;
use MockRequest;

# Everything::API::weblogmenu -- POST /api/weblogmenu/update toggles weblog-menu VARS.
# Tests the guest gate (unauthorized_if_guest modifier) and request-data validation.
# The valid-data path writes VARS via set_vars, so it is intentionally not exercised
# here (the invalid-data branch returns before any VARS access).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::weblogmenu->new();
ok($api, 'Created weblogmenu API instance');

is_deeply($api->routes, { 'update' => 'update_settings' }, 'routes: update -> update_settings');

#############################################################################
# Guest -> 401 (unauthorized_if_guest 'around')
#############################################################################

my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->update_settings($guest);
is($r->[0], $api->HTTP_UNAUTHORIZED, 'guest is unauthorized (401)');

#############################################################################
# Logged-in with non-hash body -> invalid request data
#############################################################################

my $bad = MockRequest->new(
    node_id       => 2,
    title         => 'normaluser1',
    is_guest_flag => 0,
    nodedata      => { node_id => 2, title => 'normaluser1' },
    postdata      => 'not-a-hashref',
);
$r = $api->update_settings($bad);
is($r->[0], $api->HTTP_OK, 'invalid data returns 200');
is($r->[1]{success}, 0, 'invalid data is rejected');
like($r->[1]{error}, qr/invalid request data/i, 'invalid-data error message');

done_testing();

=head1 NAME

t/139_weblogmenu_api.t - Tests for Everything::API::weblogmenu (guest gate + validation)

=cut
