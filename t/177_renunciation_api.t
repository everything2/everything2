#!/usr/bin/perl -w
# Everything::API::renunciation -- POST /api/renunciation/{transfer,nodes} (#4414).
# The admin bulk writeup-ownership transfer used to run as a side effect in
# Everything::Page::renunciation_chainsaw's buildReactData. Now admin-gated API.
# Tests gates, validation, the node-list read, and a transfer round-trip (A->B
# then back) verifying author_user + numwriteups. Self-cleaning (temp e2node +
# writeup nuked, numwriteups restored).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::renunciation;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::renunciation->new();
ok($api, 'Created renunciation API instance');
is_deeply($api->routes,
    { transfer => 'transfer_writeups', nodes => 'list_user_nodes' },
    'routes: transfer / nodes');

#############################################################################
# Gates + validation
#############################################################################
my $r = $api->transfer_writeups(MockRequest->new(node_id => 999999, is_admin_flag => 0,
    postdata => { user_from => 'a', user_to => 'b', namelist => 'x' }));
is($r->[1]{success}, 0, 'non-admin cannot transfer');
like($r->[1]{error}, qr/admin/i, 'transfer admin gate');

$r = $api->list_user_nodes(MockRequest->new(node_id => 999999, is_admin_flag => 0,
    postdata => { user => 'a' }));
is($r->[1]{success}, 0, 'non-admin cannot list nodes');

$r = $api->transfer_writeups(MockRequest->new(node_id => 113, is_admin_flag => 1, postdata => {}));
is($r->[1]{success}, 0, 'missing params rejected');

$r = $api->transfer_writeups(MockRequest->new(node_id => 113, is_admin_flag => 1,
    postdata => { user_from => 'no_such_user_xyz', user_to => 'root', namelist => 'x' }));
like($r->[1]{error}, qr/No such user/i, 'unknown from-user rejected');

#############################################################################
# Round-trip transfer against a temp e2node + writeup
#############################################################################
my $A    = $DB->getNode('normaluser25', 'user');
my $B    = $DB->getNode('normaluser26', 'user');
my $ROOT = $DB->getNode('root', 'user');
my $E2TITLE = 'Chainsaw Test E2 ZZ';

SKIP: {
    skip 'seed users missing', 7 unless ($A && $B && $ROOT);

    my $old = $DB->getNode($E2TITLE, 'e2node');
    $DB->nukeNode($old, $ROOT) if $old;

    my $e2id = $DB->insertNode($E2TITLE, $DB->getType('e2node'), $ROOT);
    my $wuid = $DB->insertNode("$E2TITLE (thing)", $DB->getType('writeup'), $A);
    $DB->sqlDelete('writeup', "writeup_id=$wuid");
    $DB->sqlInsert('writeup', {
        writeup_id => $wuid, parent_e2node => $e2id, wrtype_writeuptype => 0,
        notnew => 0, cooled => 0, feedback_policy_id => 0,
    });

    my $av = Everything::getVars($A); $av->{numwriteups} = 5;  Everything::setVars($A, $av);
    my $bv = Everything::getVars($B); $bv->{numwriteups} = 10; Everything::setVars($B, $bv);

    # transfer A -> B
    $r = $api->transfer_writeups(MockRequest->new(node_id => 113, is_admin_flag => 1,
        postdata => { user_from => 'normaluser25', user_to => 'normaluser26', namelist => $E2TITLE }));
    is($r->[1]{success}, 1, 'transfer A->B succeeds');
    is(scalar(@{$r->[1]{reparented}}), 1, 'one writeup reparented');
    is($DB->sqlSelect('author_user', 'node', "node_id=$wuid"), $B->{node_id}, 'writeup author_user is now B');
    is(int(Everything::getVars($DB->getNode('normaluser25', 'user'))->{numwriteups}), 4,  'A numwriteups decremented');
    is(int(Everything::getVars($DB->getNode('normaluser26', 'user'))->{numwriteups}), 11, 'B numwriteups incremented');

    # transfer back B -> A
    $api->transfer_writeups(MockRequest->new(node_id => 113, is_admin_flag => 1,
        postdata => { user_from => 'normaluser26', user_to => 'normaluser25', namelist => $E2TITLE }));
    is($DB->sqlSelect('author_user', 'node', "node_id=$wuid"), $A->{node_id}, 'writeup author_user is A again');

    # node-list for A includes the temp e2node
    $r = $api->list_user_nodes(MockRequest->new(node_id => 113, is_admin_flag => 1,
        postdata => { user => 'normaluser25' }));
    ok((grep { $_->{node_id} == $e2id } @{$r->[1]{generated_list}{nodes}}), 'node-list includes the temp e2node');

    # cleanup
    $DB->sqlDelete('writeup', "writeup_id=$wuid");
    my $wun = $DB->getNodeById($wuid); $DB->nukeNode($wun, $ROOT) if $wun;
    my $e2n = $DB->getNodeById($e2id); $DB->nukeNode($e2n, $ROOT) if $e2n;
    for my $uname ('normaluser25', 'normaluser26') {
        my $un = $DB->getNode($uname, 'user');
        my $v = Everything::getVars($un);
        delete $v->{numwriteups};
        Everything::setVars($un, $v);
    }
}

done_testing;
