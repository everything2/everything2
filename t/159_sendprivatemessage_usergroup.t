#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 159_sendprivatemessage_usergroup.t
#
# Covers the sendPrivateMessage htmlcode -> Everything::Application migration
# (#4349). The ~796-line htmlcode::sendPrivateMessage was deleted; its last two
# callers (Delegation::maintenance debate-reply + new-discussion announce) now
# call $APP->sendPrivateMessage. The one functionality gap the audit found was
# usergroup membership: htmlcode gated group sends on the *acting user* (always a
# member), while Application::sendUsergroupMessage gates on the *author*. The
# announce author is the Virgil bot, which is NOT a member of the gods/e2gods
# group it notifies -- so a naive repoint would have silently dropped that
# message. The new sendUsergroupMessage bypass_membership option closes the gap.
#
# This pins:
#   1. membership is STILL enforced for an ordinary non-member author (no flag)
#   2. bypass_membership lets a non-member system author reach every member
#   3. the single-user notify path (the debate-reply form) still delivers
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use TestSeed;

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $root = $DB->getNode('root', 'user');

# A non-member "system" author (stands in for the Virgil bot) + two members.
my $author = TestSeed::make_user($DB, $APP, label => 'sysbot',  experience => 1000);
my $m1     = TestSeed::make_user($DB, $APP, label => 'member1', experience => 1000);
my $m2     = TestSeed::make_user($DB, $APP, label => 'member2', experience => 1000);
ok($author && $m1 && $m2, 'dedicated author + two members');

# Dedicated usergroup (root is the privileged creator); members are the two
# dedicated users so delivery never touches shared singletons. #4267
my $ug_title = "e2e_spm_ug_$$";
my $ug_id = $DB->insertNode($ug_title, 'usergroup', $root, { title => $ug_title, groupaccess => 'public' });
ok($ug_id, 'created dedicated usergroup');
my $ug = $DB->getNodeById($ug_id, 'force');
$DB->insertIntoNodegroup($ug, $root, $m1);
$DB->insertIntoNodegroup($ug, $root, $m2);

ok(!$APP->inUsergroup($author, $ug), 'system author is NOT a member of the group');

#############################################################################
# 1. Membership is still enforced: a non-member author with no bypass is refused
#    and delivers nothing.
#############################################################################
{
    my $r = $APP->sendPrivateMessage($author, $ug_id, 'no-bypass attempt');
    is($r->{success}, 0, 'non-member author cannot message the group without bypass_membership');
    like($r->{errors}[0], qr/not a member/i, 'rejection explains non-membership');
    my $cnt = $DB->sqlSelect('COUNT(*)', 'message',
        "author_user=$author->{user_id} AND for_usergroup=$ug_id");
    is($cnt, 0, 'no group messages were delivered');
}

#############################################################################
# 2. bypass_membership: the system author reaches every member (the
#    Virgil-announces-to-a-group-it-isn't-in path the migration must preserve).
#############################################################################
{
    my $r = $APP->sendPrivateMessage($author, $ug_id, 'system announce', { bypass_membership => 1 });
    is($r->{success}, 1, 'bypass_membership lets a non-member system author message the group')
        or diag($r->{error});
    is(scalar(@{ $r->{sent_to} }), 2, 'reported delivery to both members');
    my $cnt = $DB->sqlSelect('COUNT(*)', 'message',
        "author_user=$author->{user_id}"
        . " AND for_user IN ($m1->{user_id}, $m2->{user_id})"
        . " AND for_usergroup=$ug_id");
    is($cnt, 2, 'two member inbox rows, each tagged with for_usergroup');
}

#############################################################################
# 3. Single-user notify (the debate-comment reply path / caller-1 form):
#    recipient passed as a bare node_id, no group, no flag.
#############################################################################
{
    my $r = $APP->sendPrivateMessage($author, $m1->{node_id}, 'direct notice');
    is($r->{success}, 1, 'single-user send by node_id works');
    my $cnt = $DB->sqlSelect('COUNT(*)', 'message',
        "author_user=$author->{user_id} AND for_user=$m1->{user_id}"
        . " AND for_usergroup=0 AND msgtext='direct notice'");
    is($cnt, 1, 'direct message landed in the user inbox (for_usergroup=0)');
}

# Cleanup
$DB->sqlDelete('message', "author_user=$author->{user_id}");
$DB->sqlDelete('message_outbox', "author_user=$author->{user_id}");
$DB->nukeNode($DB->getNodeById($ug_id, 'force'), -1) if $DB->getNodeById($ug_id, 'force');
TestSeed::cleanup($DB);

done_testing();
