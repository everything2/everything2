#!/usr/bin/perl -w
# Everything::API::usergroup_message_archive -- POST /api/usergroup_message_archive/copy
# (#4472, Refs #4298). The copy-group-message-to-self + reset-time-toggle mutation used to
# run inside Everything::Page::usergroup_message_archive's buildReactData off cpgroupmsg_*
# / ugma_resettime query params. It now lives here (re-verifies membership +
# allow_message_archive + per-message ownership). Tests the guest gate, a bad group, a
# real copy against `edev`, and the ownership guard, cleaning up its test messages + vars.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::usergroup_message_archive;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::usergroup_message_archive->new();
ok($api, 'Created ugma API instance');
is_deeply($api->routes, {copy => 'copy_messages'}, 'routes: copy -> copy_messages');

# Guest gate
my $r = $api->copy_messages(MockRequest->new(is_guest_flag => 1, postdata => {group => 'edev'}));
is($r->[1]{success}, 0, 'guest refused');
like($r->[1]{error}, qr/login/i, 'guest login error');

SKIP: {
    my $root = $DB->getNode('root', 'user');
    my $ug   = $DB->getNode('edev', 'usergroup');
    skip 'root/edev not present or not archive-enabled', 8
        unless ($root && $ug && Everything::isApproved($root, $ug)
            && $APP->getParameter($ug, 'allow_message_archive'));

    my $rootid = $root->{node_id};
    my $ugID   = $ug->{node_id};

    my $admin = sub {
        MockRequest->new(is_guest_flag => 0, node_id => $rootid, nodedata => $root, postdata => $_[0]);
    };

    # capture + later restore root's reset-time pref (the copy persists it)
    my $orig_reset = $APP->getVars($root)->{ugma_resettime};

    # bad group
    $r = $api->copy_messages($admin->({group => 'no_such_group_xyz123'}));
    is($r->[1]{success}, 0, 'bad group rejected');
    like($r->[1]{error}, qr/no such usergroup/i, 'no-such-group error');

    # a genuine group-archive message
    $DB->sqlInsert('message', {
        msgtext => 't193 archive test', author_user => $rootid,
        for_user => $ugID, for_usergroup => $ugID});
    my $mid = $DB->sqlSelect('LAST_INSERT_ID()');

    $r = $api->copy_messages($admin->({group => 'edev', message_ids => [$mid], reset_time => 1}));
    is($r->[1]{success}, 1, 'copy succeeds');
    is($r->[1]{copied_count}, 1, 'one message copied');
    is($r->[1]{reset_time}, 1, 'reset_time preference echoed');
    is($APP->getVars($DB->getNode('root', 'user'))->{ugma_resettime}, 1, 'reset_time pref persisted');

    my $copy_id = $DB->sqlSelect('message_id', 'message',
        "for_user=$rootid AND msgtext=" . $DB->quote('t193 archive test') . " AND message_id != $mid");
    ok($copy_id, 'a copy landed in root\'s message box');

    # ownership guard: a message NOT in this group archive is not copied
    $DB->sqlInsert('message', {
        msgtext => 't193 not group', author_user => $rootid, for_user => $rootid, for_usergroup => 0});
    my $other = $DB->sqlSelect('LAST_INSERT_ID()');
    $r = $api->copy_messages($admin->({group => 'edev', message_ids => [$other], reset_time => 0}));
    is($r->[1]{copied_count}, 0, 'message outside the group archive is not copied');

    # cleanup: test messages + restore pref
    $DB->sqlDelete('message', 'msgtext LIKE ' . $DB->quote('t193%'));
    my $rv = $APP->getVars($DB->getNode('root', 'user'));
    if (defined $orig_reset) { $rv->{ugma_resettime} = $orig_reset } else { delete $rv->{ugma_resettime} }
    Everything::setVars($DB->getNode('root', 'user'), $rv);
    $DB->updateNode($DB->getNode('root', 'user'), -1);
}

done_testing;
