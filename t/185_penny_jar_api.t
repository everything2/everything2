#!/usr/bin/perl -w
# Everything::API::e2_penny_jar -- POST /api/e2_penny_jar/give|take (#4453, Refs #4298).
#
# The community "penny jar" give/take (a shared GP pot) used to run inside
# Everything::Page::e2_penny_jar's buildReactData off give/take query params. It now
# lives here. Tests the guest gate, the GP-opt-out gate, a real give and take (with the
# GP + jar accounting), and the two soft guards (no GP to give / empty jar). Everything
# it mutates -- the shared 'penny jar' setting count and normaluser1's GP/vars -- is
# captured up front and restored at the end so re-runs stay stable.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::e2_penny_jar;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::e2_penny_jar->new();
ok($api, 'Created e2_penny_jar API instance');
is_deeply($api->routes, {give => 'give_penny', take => 'take_penny'},
    'routes: give -> give_penny, take -> take_penny');

#############################################################################
# Guest gate -- refused for both actions (200 + success=0), no state touched
#############################################################################
for my $pair (['give', 'give_penny'], ['take', 'take_penny']) {
    my ($label, $method) = @$pair;
    my $r = $api->$method(MockRequest->new(is_guest_flag => 1));
    is($r->[0], $api->HTTP_OK, "$label returns 200 for guest");
    is($r->[1]{success}, 0, "$label refused for guest");
    like($r->[1]{error}, qr/logged in/i, "$label guest error mentions login");
}

my $penny = $DB->getNode('penny jar', 'setting');
my $nu1   = $DB->getNode('normaluser1', 'user');

SKIP: {
    skip 'penny jar setting / normaluser1 not present', 1 unless ($penny && $nu1);

    # ---- capture originals ---------------------------------------------------
    my $pvars       = $APP->getVars($penny);
    my $orig_jar    = $pvars->{1} || 0;
    my $orig_gp     = $nu1->{GP}  || 0;
    my $uvars       = $APP->getVars($nu1);
    my $orig_optout = $uvars->{GPoptout};

    my $set_jar = sub {
        my $n = shift;
        my $v = $APP->getVars($penny);
        $v->{1} = $n;
        Everything::setVars($penny, $v);
        $DB->updateNode($penny, -1);
    };
    my $set_gp = sub {
        my $n = shift;
        $nu1->{GP} = $n;
        $DB->updateNode($nu1, -1);
    };
    my $set_optout = sub {
        my $on = shift;
        my $v = $APP->getVars($nu1);
        if   ($on) { $v->{GPoptout} = 1 }
        else       { delete $v->{GPoptout} }
        Everything::setVars($nu1, $v);
        $DB->updateNode($nu1, -1);
    };

    # ---- known starting state: jar=3, GP=5, no opt-out -----------------------
    $set_optout->(0);
    $set_jar->(3);
    $set_gp->(5);

    #########################################################################
    # give: +1 penny to jar, -1 GP from the giver
    #########################################################################
    my $r = $api->give_penny(MockRequest->new(is_guest_flag => 0, nodedata => $nu1));
    is($r->[1]{success}, 1, 'give succeeds');
    like($r->[1]{message}, qr/gave a penny/i, 'give message');
    is($r->[1]{pennies_in_jar}, 4, 'give: jar 3 -> 4');
    is($r->[1]{user_gp}, 4, 'give: GP 5 -> 4');

    #########################################################################
    # take: -1 penny from jar, +1 GP to the taker
    #########################################################################
    $r = $api->take_penny(MockRequest->new(is_guest_flag => 0, nodedata => $nu1));
    is($r->[1]{success}, 1, 'take succeeds');
    like($r->[1]{message}, qr/took a penny/i, 'take message');
    is($r->[1]{pennies_in_jar}, 3, 'take: jar 4 -> 3');
    is($r->[1]{user_gp}, 5, 'take: GP 4 -> 5');

    #########################################################################
    # give soft guard: no GP to give -> success=0, jar untouched
    #########################################################################
    $set_gp->(0);
    $r = $api->give_penny(MockRequest->new(is_guest_flag => 0, nodedata => $nu1));
    is($r->[1]{success}, 0, 'give with 0 GP refused');
    like($r->[1]{message}, qr/do not have any GP/i, 'give-broke message');
    is($r->[1]{pennies_in_jar}, 3, 'give-broke: jar unchanged');

    #########################################################################
    # take soft guard: empty jar -> success=0
    #########################################################################
    $set_gp->(5);
    $set_jar->(0);
    $r = $api->take_penny(MockRequest->new(is_guest_flag => 0, nodedata => $nu1));
    is($r->[1]{success}, 0, 'take from empty jar refused');
    like($r->[1]{message}, qr/no more pennies/i, 'take-empty message');

    #########################################################################
    # GP opt-out gate -> refused before any mutation
    #########################################################################
    $set_jar->(3);
    $set_optout->(1);
    $r = $api->give_penny(MockRequest->new(is_guest_flag => 0, nodedata => $nu1));
    is($r->[1]{success}, 0, 'opt-out user refused');
    like($r->[1]{error}, qr/not interested/i, 'opt-out error');

    # ---- restore everything --------------------------------------------------
    $set_optout->($orig_optout ? 1 : 0);
    $set_jar->($orig_jar);
    $set_gp->($orig_gp);
}

done_testing;
