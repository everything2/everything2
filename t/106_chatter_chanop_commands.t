#!/usr/bin/perl
#
# 106_chatter_chanop_commands.t
#
# Coverage for the chatter commands restored into
# Everything::Application::processMessageCommand from the retired `message`
# opcode: /drag, /fakeborg, /topic (chanop/admin), /sayas (admin only), and
# /ignore + /unignore (any logged-in user). Each is exercised for the
# authorized path (side effect + success), the permission gate, and (where
# relevant) the modern mechanism it reuses.
#
# Uses existing seed users (root = admin/authorized; normaluser1 = plain/denied;
# normaluser3 = the acted-upon target). Side effects (room move, suspension,
# topic, messages, ignores) are torn down at the end.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $APP->{db};
ok($APP, 'application initialized');

my $edb     = $DB->getNode('EDB', 'user');
my $webster = $DB->getNode('Webster 1913', 'user');

my $admin = $DB->getNode('root', 'user');
my $plain = $DB->getNode('normaluser1', 'user');
my $target = $DB->getNode('normaluser3', 'user');

unless ($admin && $plain && $target && $edb) {
    plan skip_all => 'required seed users (root/normaluser1/normaluser3/EDB) not present';
}
ok($APP->isAdmin($admin), 'root is admin (authorized actor)');
ok(!$APP->isChanop($plain, "nogods") && !$APP->isAdmin($plain),
    'normaluser1 is unprivileged (denied actor)');

# Act "outside" deterministically; remember the target's room to restore.
$admin->{in_room} = 0;
my $target_room_before = $target->{in_room};
my $tid = $target->{node_id};

my $vars = {};

#############################################################################
subtest '/drag moves a user and pins them, chanop/admin only' => sub {
    my $r = $APP->processMessageCommand($admin, "/drag normaluser3", $vars);
    ok($r && $r->{success}, '/drag succeeds for admin');
    ok($DB->sqlSelect('count(*)', 'message',
        "for_user=$tid AND author_user=$edb->{node_id} AND msgtext LIKE '%dragged%'") >= 1,
        'target receives an EDB "dragged" message');
    ok($DB->sqlSelect('count(*)', 'suspension', "suspension_user=$tid") >= 1,
        'target is suspended (changeroom)');

    my $denied = $APP->processMessageCommand($plain, "/drag normaluser3", $vars);
    is($denied->{success}, 0, '/drag denied for non-chanop');
    like($denied->{error}, qr/chanop or admin/i, 'permission error message');
};

#############################################################################
subtest '/fakeborg announces a fake borging, chanop/admin only' => sub {
    my $r = $APP->processMessageCommand($admin, "/fakeborg somenoder", $vars);
    ok($r && $r->{success}, '/fakeborg succeeds for admin');
    ok($DB->sqlSelect('count(*)', 'message',
        "author_user=$edb->{node_id} AND for_user=0 AND msgtext LIKE '%swallowed [somenoder]%'") >= 1,
        'EDB posts a public swallow message');

    my $denied = $APP->processMessageCommand($plain, "/fakeborg x", $vars);
    is($denied->{success}, 0, '/fakeborg denied for non-chanop');
};

#############################################################################
subtest '/topic sets the room topic, chanop/admin only' => sub {
    my $settingsnode = $DB->getNode('Room topics', 'setting');
  SKIP: {
        skip "'Room topics' setting not present", 3 unless $settingsnode;
        my %restore = %{ $APP->getVars($settingsnode) };

        my $r = $APP->processMessageCommand($admin, "/topic Test Topic 106", $vars);
        ok($r && $r->{success}, '/topic succeeds for admin');
        is($APP->getVars($DB->getNode('Room topics', 'setting'))->{0},
            'Test Topic 106', "outside-room topic written to 'Room topics' setting");

        my $denied = $APP->processMessageCommand($plain, "/topic nope", $vars);
        is($denied->{success}, 0, '/topic denied for non-chanop');

        Everything::setVars($DB->getNode('Room topics', 'setting'), \%restore);
    }
};

#############################################################################
subtest '/sayas speaks as a persona, admin only' => sub {
  SKIP: {
        skip 'Webster 1913 persona not present', 2 unless $webster;
        my $r = $APP->processMessageCommand($admin, "/sayas webster hello from the dictionary", $vars);
        ok($r && $r->{success}, '/sayas succeeds for admin');
        ok($DB->sqlSelect('count(*)', 'message',
            "author_user=$webster->{node_id} AND for_user=0 AND msgtext LIKE '%from the dictionary%'") >= 1,
            'public message authored by the persona');
    }

    my $denied = $APP->processMessageCommand($plain, "/sayas webster hi", $vars);
    is($denied->{success}, 0, '/sayas denied for non-admin');
    like($denied->{error}, qr/administrator/i, 'admin-only error message');
};

#############################################################################
subtest '/ignore and /unignore toggle messageignore' => sub {
    my $ic = sub {
        $DB->sqlSelect('count(*)', 'messageignore',
            "messageignore_id=$plain->{node_id} AND ignore_node=$tid");
    };
    $DB->sqlDelete('messageignore', "messageignore_id=$plain->{node_id} AND ignore_node=$tid");
    is($ic->(), 0, 'not ignoring before');

    my $r1 = $APP->processMessageCommand($plain, "/ignore normaluser3", $vars);
    ok($r1 && $r1->{success}, '/ignore succeeds for a normal user');
    is($ic->(), 1, 'messageignore row created');

    my $r2 = $APP->processMessageCommand($plain, "/unignore normaluser3", $vars);
    ok($r2 && $r2->{success}, '/unignore succeeds');
    is($ic->(), 0, 'messageignore row removed');

    is($APP->processMessageCommand($plain, "/ignore nonexistent_user_zzz_106", $vars)->{success},
        0, '/ignore unknown user is rejected');
};

#############################################################################
# /borg stores a TIMESTAMP (not a 1 flag) + expire_borg_if_due lifecycle
# (drives the chatterbox countdown + the one-time "spit you out" notice)
#############################################################################
subtest 'borg stores a timestamp and expires on schedule' => sub {
    my $tnode = $DB->getNodeById($tid);

    # clean any prior borg state on the target
    my $pre = $APP->getVars($tnode);
    delete $pre->{borged}; delete $pre->{lastborg};
    Everything::setVars($tnode, $pre);

    my $nb_before = $pre->{numborged} || 0;

    # /borg (admin) sets the target's `borged` to a RECENT unix timestamp
    my $r = $APP->processMessageCommand($admin, "/borg normaluser3", $vars);
    ok($r, '/borg ran');
    my $tvars = $APP->getVars($DB->getNodeById($tid));
    ok($tvars->{borged} && $tvars->{borged} > (time - 60) && $tvars->{borged} > 1,
        'borged is a recent timestamp, not a 1 flag');
    is(($tvars->{numborged} || 0), $nb_before + 1, 'numborged incremented (borg escalation)');

    # A fresh borg is NOT due to expire
    is($APP->expire_borg_if_due($tnode, $tvars), 0, 'fresh borg is not expired');
    ok($tvars->{borged}, 'borged still set');

    # An old borg (past the 300 + 60*2*numborged cooldown) expires + heals
    $tvars->{numborged} = 1;
    $tvars->{borged}    = time - 99999;
    is($APP->expire_borg_if_due($tnode, $tvars), 1, 'old borg expires');
    ok(!$tvars->{borged}, 'borged cleared on expiry');
    ok($tvars->{lastborg}, 'lastborg recorded');

    # A legacy `borged = 1` flag reads as long-expired -> self-heals
    $tvars->{borged} = 1;
    is($APP->expire_borg_if_due($tnode, $tvars), 1, 'legacy borged=1 flag heals');
    ok(!$tvars->{borged}, 'stale flag cleared');

    # restore
    delete $tvars->{borged}; delete $tvars->{lastborg}; delete $tvars->{numborged};
    Everything::setVars($DB->getNodeById($tid), $tvars);
};

# -- teardown --------------------------------------------------------------
$DB->sqlDelete('message', "author_user=$edb->{node_id} AND for_user IN ($tid,$admin->{node_id},0)");
$DB->sqlDelete('message',
    "author_user=$edb->{node_id} AND (msgtext LIKE '%dragged%' OR msgtext LIKE '%swallowed [somenoder]%')");
$DB->sqlDelete('message', "author_user=$webster->{node_id} AND msgtext LIKE '%from the dictionary%'")
    if $webster;
$DB->sqlDelete('messageignore', "messageignore_id=$plain->{node_id} AND ignore_node=$tid");
$DB->sqlDelete('suspension', "suspension_user=$tid");
$DB->sqlDelete('room', "member_user=$tid");
$DB->sqlUpdate('user', { in_room => ($target_room_before || 0) }, "user_id=$tid");

done_testing();
