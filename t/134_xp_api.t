#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::xp;
use MockRequest;

# Everything::API::xp -- XP stats + the one-time XP recalculation. Tests the auth gate,
# the stats read path (read-only), and recalculate's guard rails. It deliberately does
# NOT drive a real recalculation (that mutates XP/VARS irreversibly) -- only the
# pre-mutation guards (login, confirmation) are exercised.

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::xp->new();
ok($api, 'Created xp API instance');

is_deeply($api->routes, { 'recalculate' => 'recalculate', 'stats' => 'get_stats' },
    'routes: stats -> get_stats, recalculate -> recalculate');

my $normal_user = $DB->getNode('normaluser1', 'user');
ok($normal_user, 'got normaluser1');

#############################################################################
# get_stats: auth gate + read-only stats contract
#############################################################################

my $guest = MockRequest->new(is_guest_flag => 1);
my $r = $api->get_stats($guest);
is($r->[0], $api->HTTP_OK, 'guest get_stats returns 200');
is($r->[1]{success}, 0, 'guest get_stats fails');
like($r->[1]{error}, qr/login required/i, 'guest told to log in');

my $logged_in = MockRequest->new(
    node_id       => $normal_user->{node_id},
    title         => $normal_user->{title},
    is_guest_flag => 0,
    nodedata      => $normal_user,
);

$r = $api->get_stats($logged_in);
is($r->[0], $api->HTTP_OK, 'user get_stats returns 200');
is($r->[1]{success}, 1, 'user get_stats succeeds');
is($r->[1]{username}, $normal_user->{title}, 'stats are for the requesting user');
for my $field (qw(currentXP writeupCount upvotesReceived coolsReceived recalculatedXP gpBonus)) {
    ok(defined $r->[1]{$field}, "stats include $field");
    like($r->[1]{$field}, qr/^-?\d+$/, "$field is an integer");
}
ok(exists $r->[1]{canRecalculate}, 'canRecalculate eligibility flag present');

#############################################################################
# recalculate: guard rails (no real recalculation performed)
#############################################################################

$r = $api->recalculate($guest);
is($r->[0], $api->HTTP_OK, 'guest recalculate returns 200');
is($r->[1]{success}, 0, 'guest cannot recalculate');
like($r->[1]{error}, qr/login required/i, 'guest told to log in');

# Logged in but did not confirm -> must-confirm guard (stops before any mutation).
my $unconfirmed = MockRequest->new(
    node_id       => $normal_user->{node_id},
    title         => $normal_user->{title},
    is_guest_flag => 0,
    nodedata      => $normal_user,
    vars          => {},
    postdata      => {},   # no `confirmed`
);
$r = $api->recalculate($unconfirmed);
is($r->[0], $api->HTTP_OK, 'unconfirmed recalculate returns 200');
is($r->[1]{success}, 0, 'unconfirmed recalculate is refused');
like($r->[1]{error}, qr/confirm/i, 'refusal mentions confirmation');

done_testing();

=head1 NAME

t/134_xp_api.t - Tests for Everything::API::xp (stats + recalculation guards)

=cut
