#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use Test::More;
use JSON;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';
use lib "$FindBin::Bin/lib";

use Everything;
use Everything::SecurityLog qw(:events);
use Everything::API::admin;
use MockUser;
use MockRequest;

# Coverage for POST /api/admin/users/cleanup (the_old_hooked_pole replacement)
# plus the _do_lock_account / _blacklist_ip helpers it shares with lock_user.
#
# Deliberately a DEDICATED file: these tests create/delete/lock throwaway user
# nodes, and that destructive churn flaked badly when bolted onto the end of the
# 100+-test t/051 (shared-state contamination, #4267). On a clean process the
# operations are deterministic. All targets are uniquely-named throwaway users
# created in setup and nuked in teardown; the only shared seeds touched are the
# actor identities (root / e2e_editor / e2e_user), which are read, not mutated.

initEverything();

my $APP = $Everything::APP;
my $DB  = $APP->{db};

my $admin_user   = $DB->getNode('root', 'user');
my $editor_user  = $DB->getNode('e2e_editor', 'user');
my $regular_user = $DB->getNode('e2e_user', 'user');

my $api = Everything::API::admin->new();

# Warm the user nodetype (tableArray + deleters group) before the destructive
# work so updateNode persists aux-table writes and canDeleteNode is deterministic
# even on a cold cache (first run after a build).
$DB->getNodeById($admin_user->{node_id}, 'force');
my $user_type = $DB->getType('user');

my $suffix = "cln$$";
my @created;

# Make a throwaway user node, then (re)create its user/document aux rows
# explicitly rather than relying on updateNode materialization (flaky cold).
# Only the PK is NOT NULL-without-default, so a minimal insert is safe; lasttime
# is nullable (NULL = never-logged-in = safe to delete).
my $mk_user = sub {
    my (%opt) = @_;
    my $uid = $DB->insertNode($opt{title}, $user_type, $admin_user, undef, 1);
    push @created, $uid if $uid;
    $DB->sqlDelete('user', "user_id=$uid");
    my $urow = { user_id => $uid, acctlock => ($opt{acctlock} // 0) };
    $urow->{lasttime} = $opt{lasttime} if defined $opt{lasttime};
    $DB->sqlInsert('user', $urow);
    if (defined $opt{doctext}) {
        $DB->sqlDelete('document', "document_id=$uid");
        $DB->sqlInsert('document', { document_id => $uid, doctext => $opt{doctext} });
    }
    $DB->getNodeById($uid, 'force');   # refresh cache with the complete row
    return $uid;
};

# canDeleteNode = isApproved($USER, user-type deleters_user) -- only gods may
# delete a user node, so the delete path needs an admin actor; editors can only
# lock. (The old page reported "deleted" even when a non-god editor's nukeNode
# no-op'd; the API now falls back to locking and reports it honestly.)
my $del_name  = "e2e_${suffix}_del";        # safe + god -> deleted
my $del_uid   = $mk_user->(title => $del_name);
my $lock_name = "e2e_${suffix}_lock";       # logged in -> locked
my $lock_uid  = $mk_user->(title => $lock_name, lasttime => '2020-01-01 12:00:00');
my $efb_name  = "e2e_${suffix}_efallback";  # safe + editor -> lock fallback
my $efb_uid   = $mk_user->(title => $efb_name);
my $bad_name  = "e2e_${suffix}_nosuchuser"; # never created -> skipped

# editor gate: non-editor refused
{
    my $req = MockRequest->new(
        node_id => $regular_user->{node_id}, title => $regular_user->{title},
        nodedata => $regular_user, is_editor_flag => 0,
        postdata => { usernames => [$del_name] }
    );
    my $r = $api->cleanup_users($req);
    is($r->[0], $api->HTTP_OK, 'cleanup: non-editor still HTTP_OK');
    is($r->[1]{success}, 0, 'cleanup: non-editor refused');
}

# god actor: a safe user is actually deleted
{
    my $req = MockRequest->new(
        node_id => $admin_user->{node_id}, title => $admin_user->{title},
        nodedata => $admin_user, is_editor_flag => 1,
        postdata => { usernames => [$del_name] }
    );
    my $r = $api->cleanup_users($req);
    is($r->[1]{success}, 1, 'cleanup: god success');
    my %by = map { $_->{input} => $_ } @{ $r->[1]{results} };
    is($by{$del_name}{action}, 'deleted', 'god: safe user deleted');
    ok(!$DB->getNodeById($del_uid, 'force'), 'god: deleted user gone from node table');
}

# editor actor: lock logged-in, lock-fallback on safe (can't delete users), skip invalid
{
    my $req = MockRequest->new(
        node_id => $editor_user->{node_id}, title => $editor_user->{title},
        nodedata => $editor_user, is_editor_flag => 1,
        postdata => { usernames => [$lock_name, $efb_name, $bad_name] }
    );
    my $r = $api->cleanup_users($req);
    is($r->[0], $api->HTTP_OK, 'cleanup: editor HTTP_OK');
    is($r->[1]{success}, 1, 'cleanup: editor success');

    my %by = map { $_->{input} => $_ } @{ $r->[1]{results} };
    is($by{$lock_name}{action}, 'locked',  'logged-in user locked');
    is($by{$efb_name}{action},  'locked',  "editor can't delete user -> locked (not false-deleted)");
    is($by{$bad_name}{action},  'skipped', 'invalid username skipped');
    like(join(' ', @{ $by{$bad_name}{reasons} }), qr/isn't a valid user/, 'invalid-user reason');

    ok($DB->getNodeById($efb_uid, 'force'), 'editor-fallback user still present (locked, not deleted)');
    is($DB->sqlSelect('acctlock', 'user', "user_id=$lock_uid"), $editor_user->{node_id},
        'locked user acctlock = editor node_id (shared _do_lock_account)');
}

# smite path: homenode blanked + audit nodenote (noter 0, no notification)
{
    my $spam_name = "e2e_${suffix}_spam";
    my $spam_uid  = $mk_user->(title => $spam_name, lasttime => '2020-02-02 02:02:02',
                               doctext => 'BUY CHEAP THINGS');
    my $req = MockRequest->new(
        node_id => $editor_user->{node_id}, title => $editor_user->{title},
        nodedata => $editor_user, is_editor_flag => 1,
        postdata => { usernames => [$spam_name], smite => 1 }
    );
    my $r = $api->cleanup_users($req);
    my ($res) = grep { $_->{input} eq $spam_name } @{ $r->[1]{results} };
    is($res->{action}, 'locked', 'smite: spammer locked');
    like(join(' ', @{ $res->{reasons} }), qr/Blanked homenode/, 'smite: homenode blanked');
    is(($DB->sqlSelect('doctext', 'document', "document_id=$spam_uid") // ''), '',
        'smite: homenode doctext cleared');
    is($DB->sqlSelect('COUNT(*)', 'nodenote',
            "nodenote_nodeid=$spam_uid AND notetext LIKE 'Spammer: smitten%'"), 1,
        'smite: audit nodenote written');
}

# _blacklist_ip helper (former blacklistIP htmlcode) in isolation
{
    my $ip = '203.0.113.77';   # TEST-NET-3
    $DB->sqlDelete('ipblacklist', "ipblacklist_ipaddress='$ip'");
    my $r1 = $api->_blacklist_ip($ip, 'unit test reason', $editor_user);
    like($r1, qr/added $ip to IP blacklist/i, '_blacklist_ip: first add reported');
    is($DB->sqlSelect('COUNT(*)', 'ipblacklist', "ipblacklist_ipaddress='$ip'"), 1,
        '_blacklist_ip: blacklist row created');
    like($api->_blacklist_ip('not.an.ip', 'x', $editor_user), qr/not a valid IP/,
        '_blacklist_ip: rejects bad IP');
    $DB->sqlDelete('ipblacklist', "ipblacklist_ipaddress='$ip'");
}

# teardown: nuke any surviving throwaway users + side rows. skip_maintenance=1 so
# the nuke doesn't fire user_delete (which would seclog the unset global USER).
for my $uid (@created) {
    my $n = $DB->getNodeById($uid, 'force');
    $DB->nukeNode($n, -1, 0, 1) if $n;
    $DB->sqlDelete('user', "user_id=$uid");
    $DB->sqlDelete('nodenote', "nodenote_nodeid=$uid");
    $DB->sqlDelete('document', "document_id=$uid");
}

done_testing();
