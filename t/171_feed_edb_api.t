#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::feed_edb;
use MockRequest;

# Everything::API::feed_edb -- POST /api/feed_edb/borg. The "simulate being borged by EDB"
# self-mutation used to run as a side effect in the page controller on a ?numborgings= param;
# it now lives here (#4390 -> API). Admin-only; borgs/unborgs the calling admin: sets their
# numborged/borged VARS and flips room.borgd. Tests the gates, validation, and the mutation.
# The mock admin uses a node_id with no room row, so the room sqlUpdate is a harmless 0-row write.

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::feed_edb->new();
ok($api, 'Created feed_edb API instance');
is_deeply($api->routes, { 'borg' => 'set_borgings' }, 'routes: borg -> set_borgings');

#############################################################################
# Guest -> login required
#############################################################################
my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->set_borgings($guest);
is($r->[0], $api->HTTP_OK,    'guest borg returns 200');
is($r->[1]{success}, 0,       'guest cannot borg');
like($r->[1]{error}, qr/login required/i, 'login-required error');

#############################################################################
# Logged-in non-admin -> admins only
#############################################################################
my $nonadmin = MockRequest->new(
    is_guest_flag => 0, is_admin_flag => 0,
    nodedata => { node_id => 999999 }, vars => {},
    postdata => { numborgings => 5 },
);
$r = $api->set_borgings($nonadmin);
is($r->[1]{success}, 0,        'non-admin cannot borg');
like($r->[1]{error}, qr/admin/i, 'admins-only error');

#############################################################################
# Admin, non-integer numborgings -> validation error
#############################################################################
my $bad = MockRequest->new(
    is_guest_flag => 0, is_admin_flag => 1,
    nodedata => { node_id => 999999 }, vars => {},
    postdata => { numborgings => 'abc' },
);
$r = $api->set_borgings($bad);
is($r->[1]{success}, 0,          'non-integer numborgings rejected');
like($r->[1]{error}, qr/integer/i, 'integer-required error');

#############################################################################
# Admin borg (numborgings = 5) -> success + VARS mutated
#############################################################################
my $admin = MockRequest->new(
    is_guest_flag => 0, is_admin_flag => 1,
    nodedata => { node_id => 999999 }, vars => {},
    postdata => { numborgings => 5 },
);
$r = $api->set_borgings($admin);
is($r->[0], $api->HTTP_OK,         'admin borg returns 200');
is($r->[1]{success}, 1,            'admin borg succeeds');
is($r->[1]{current_count}, 5,      'current_count reflects the borg');
like($r->[1]{message}, qr/borged 5 times/i, 'borg message');
is($admin->user->VARS->{numborged}, 5, 'VARS numborged set to 5');
ok($admin->user->VARS->{borged},       'VARS borged timestamp set');

#############################################################################
# Admin unborg (numborgings = 0) -> count 0, borged cleared
#############################################################################
my $admin2 = MockRequest->new(
    is_guest_flag => 0, is_admin_flag => 1,
    nodedata => { node_id => 999999 }, vars => { numborged => 5, borged => time },
    postdata => { numborgings => 0 },
);
$r = $api->set_borgings($admin2);
is($r->[1]{success}, 1,            'admin unborg succeeds');
is($r->[1]{current_count}, 0,      'unborg resets count to 0');
like($r->[1]{message}, qr/unborged/i, 'unborg message');
ok(!exists $admin2->user->VARS->{borged}, 'borged cleared on unborg');

done_testing();

=head1 NAME

t/171_feed_edb_api.t - Tests for Everything::API::feed_edb (gates + borg/unborg mutation)

=cut
