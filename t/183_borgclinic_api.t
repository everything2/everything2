#!/usr/bin/perl -w
# Everything::API::borgclinic -- POST /api/borgclinic/setborg (#4449, Refs #4298).
#
# The admin "set a user's borg count" action used to run inside
# Everything::Page::the_borg_clinic's buildReactData (setVars(numborged) off query
# params, during render). It now lives here, admin-gated. Tests the gate, validation
# (missing user, non-integer count), user-not-found, and the actual numborged write
# (read-modify-write, negatives allowed, with cleanup).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::borgclinic;
use MockRequest;
use TestSeed;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::borgclinic->new();
ok($api, 'Created borgclinic API instance');
is_deeply($api->routes, {'setborg' => 'set_borg_count'}, 'routes: setborg -> set_borg_count');

#############################################################################
# Non-admin -> refused (200 + success=0, never a 4xx from an API)
#############################################################################
my $nonadmin = MockRequest->new(is_admin_flag => 0, postdata => {user => 'normaluser1', count => 5});
my $r = $api->set_borg_count($nonadmin);
is($r->[0], $api->HTTP_OK, 'non-admin returns 200');
is($r->[1]{success}, 0, 'non-admin cannot set borg count');
like($r->[1]{error}, qr/admin/i, 'admin-required error');

#############################################################################
# Admin, validation: missing user / non-integer count
#############################################################################
$r = $api->set_borg_count(MockRequest->new(is_admin_flag => 1, postdata => {count => 5}));
is($r->[1]{success}, 0, 'missing user rejected');
like($r->[1]{error}, qr/user/i, 'user-required error');

$r = $api->set_borg_count(MockRequest->new(is_admin_flag => 1, postdata => {user => 'normaluser1', count => 'abc'}));
is($r->[1]{success}, 0, 'non-integer count rejected');
like($r->[1]{error}, qr/integer/i, 'integer-required error');

#############################################################################
# Admin, unknown target -> not found
#############################################################################
$r = $api->set_borg_count(MockRequest->new(is_admin_flag => 1, postdata => {user => 'no_such_user_xyz123', count => 5}));
is($r->[1]{success}, 0, 'unknown user rejected');
like($r->[1]{error}, qr/not found/i, 'user-not-found error');

#############################################################################
# Admin, real set (read-modify-write), negatives, then clean up
#############################################################################
# A DEDICATED user, not the shared normaluser1 seed: this section does a VARS
# read-modify-write and then asserts an unrelated var ('borg_keepme') survived.
# getVars/setVars rewrite the whole VARS blob, so any other test concurrently
# mutating the same user's VARS under `prove -j` would clobber borg_keepme
# between our set and re-read. A per-process throwaway user (auto-nuked by
# TestSeed) can't be raced. #4267-style isolation.
my $tnode  = TestSeed::make_user($DB, $Everything::APP, label => 'borgclinic');
my $TARGET = $tnode ? $tnode->{title} : 'normaluser1';
SKIP: {
    skip "could not create target user", 6 unless $tnode;

    my $pre = Everything::getVars($tnode);
    $pre->{borg_keepme} = 'intact';
    $pre->{numborged}   = 0;
    Everything::setVars($tnode, $pre);

    $r = $api->set_borg_count(MockRequest->new(
        is_admin_flag => 1, postdata => {user => $TARGET, count => 42}));
    is($r->[1]{success}, 1, 'admin set succeeds');
    is($r->[1]{borg_count}, 42, 'echoes the new borg count as an int');

    my $after = Everything::getVars($DB->getNode($TARGET, 'user'));
    is($after->{numborged}, 42, 'numborged was written');
    is($after->{borg_keepme}, 'intact', 'other vars left untouched');

    # negative = "borg insurance"
    $r = $api->set_borg_count(MockRequest->new(
        is_admin_flag => 1, postdata => {user => $TARGET, count => -1}));
    is($r->[1]{success}, 1, 'negative count accepted');
    is($r->[1]{borg_count}, -1, 'negative borg count (insurance) echoed');

    my $clean = Everything::getVars($DB->getNode($TARGET, 'user'));
    delete $clean->{borg_keepme};
    $clean->{numborged} = 0;
    Everything::setVars($DB->getNode($TARGET, 'user'), $clean);
}

done_testing;
