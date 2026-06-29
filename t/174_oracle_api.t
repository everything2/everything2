#!/usr/bin/perl -w
# Everything::API::oracle -- POST /api/oracle/setvar (#4405). The admin "set an
# arbitrary var on an arbitrary user" action used to run as a side effect in
# Everything::Page::the_oracle's buildReactData (query params -> setVars on
# ANOTHER user during render). It now lives here, admin-gated. Tests the gate,
# validation, user-not-found, and the actual var write (with cleanup).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::oracle;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::oracle->new();
ok($api, 'Created oracle API instance');
is_deeply($api->routes, { 'setvar' => 'set_user_var' }, 'routes: setvar -> set_user_var');

#############################################################################
# Non-admin -> admin access required (even a logged-in non-admin)
#############################################################################
my $nonadmin = MockRequest->new(
    node_id => 999999, is_admin_flag => 0,
    postdata => { user => 'normaluser1', var => 'oracle_test_var', value => 'x' },
);
my $r = $api->set_user_var($nonadmin);
is($r->[0], $api->HTTP_OK, 'non-admin returns 200');
is($r->[1]{success}, 0,    'non-admin cannot set vars');
like($r->[1]{error}, qr/admin/i, 'admin-required error');

#############################################################################
# Admin, missing params -> validation error
#############################################################################
my $missing = MockRequest->new(node_id => 113, is_admin_flag => 1, postdata => {});
$r = $api->set_user_var($missing);
is($r->[1]{success}, 0, 'missing user/var rejected');
like($r->[1]{error}, qr/required/i, 'validation error');

#############################################################################
# Admin, unknown target user -> not found
#############################################################################
my $notfound = MockRequest->new(
    node_id => 113, is_admin_flag => 1,
    postdata => { user => 'no_such_user_xyz123', var => 'v', value => 'w' },
);
$r = $api->set_user_var($notfound);
is($r->[1]{success}, 0, 'unknown user rejected');
like($r->[1]{error}, qr/not found/i, 'user-not-found error');

#############################################################################
# Admin, real target -> the var is written (read-modify-write), then clean up
#############################################################################
my $TARGET = 'normaluser1';
my $tnode  = $DB->getNode($TARGET, 'user');
SKIP: {
    skip "$TARGET seed user not present", 4 unless $tnode;

    # Seed an unrelated var so we can prove we don't clobber the rest.
    my $pre = Everything::getVars($tnode);
    $pre->{oracle_keepme} = 'intact';
    delete $pre->{oracle_test_var};
    Everything::setVars($tnode, $pre);

    my $ok = MockRequest->new(
        node_id => 113, is_admin_flag => 1,
        postdata => { user => $TARGET, var => 'oracle_test_var', value => 'oraclehello' },
    );
    $r = $api->set_user_var($ok);
    is($r->[1]{success}, 1, 'admin set succeeds');
    is($r->[1]{var}, 'oracle_test_var', 'echoes the var name');

    my $after = Everything::getVars($DB->getNode($TARGET, 'user'));
    is($after->{oracle_test_var}, 'oraclehello', 'target var was written');
    is($after->{oracle_keepme}, 'intact', 'other vars left untouched');

    # Cleanup: remove the test vars.
    my $clean = Everything::getVars($DB->getNode($TARGET, 'user'));
    delete $clean->{oracle_test_var};
    delete $clean->{oracle_keepme};
    Everything::setVars($DB->getNode($TARGET, 'user'), $clean);
}

done_testing;
