#!/usr/bin/perl
#
# 149_bookmark_notify.t -- parity test for Everything::API::cool::_notify_bookmark (#4292).
#
# The bookmark opcode used to send Cool Man Eddie a notification on bookmark:
#   * bookmarking a WRITEUP -> notify that writeup's single author
#   * bookmarking an E2NODE -> notify EVERY writeup author in the node's group
# When the opcode was retired, toggle_bookmark only covered the single-writeup case.
# This pins the restored e2node-group behavior + the self-bookmark skip.
#
use strict;
use warnings;
use Test::More;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';
use lib '/var/everything/t/lib';

use Everything;
use Everything::API::cool;
use TestSeed;

initEverything();

my $APP = $Everything::APP;
my $DB  = $APP->{db};

my $api   = Everything::API::cool->new();
my $eddie = $DB->getNode('Cool Man Eddie', 'user');
ok($eddie, 'Cool Man Eddie exists');

# Two authors + a separate bookmarker. Dedicated users: eddie_msgs_to() counts
# eddie->author messages by msgtext substring (NOT scoped to $mark), so a
# concurrent bookmark-notify to a shared normaluser would skew the counts under
# prove -j4. #4267
my $authorA    = TestSeed::make_user($DB, $APP, label => 'authorA', experience => 1000);
my $authorB    = TestSeed::make_user($DB, $APP, label => 'authorB', experience => 1000);
my $bookmarker = TestSeed::make_user($DB, $APP, label => 'bookmarker', experience => 1000);
ok($authorA && $authorB && $bookmarker, 'got three distinct dedicated users');

my $mark = "t149-bm-$$";

# Count Eddie bookmark messages to a given user whose text matches $like.
sub eddie_msgs_to {
  my ($uid, $like) = @_;
  return $DB->sqlSelect('COUNT(*)', 'message',
    "author_user=$eddie->{user_id} AND for_user=$uid AND msgtext LIKE "
    . $DB->{dbh}->quote("%$like%"));
}

# --- fixture: an e2node containing one writeup from each author ---
my $e2_title  = "$mark node";
my $e2node_id = $DB->insertNode($e2_title, 'e2node', $bookmarker, { title => $e2_title });
my $wuA = $DB->insertNode("$mark wuA", 'writeup', $authorA, { parent_e2node => $e2node_id });
my $wuB = $DB->insertNode("$mark wuB", 'writeup', $authorB, { parent_e2node => $e2node_id });
ok($e2node_id && $wuA && $wuB, 'created e2node + two writeups');

# root performs the group inserts (insertIntoNodegroup gates on canUpdateNode).
my $root = $DB->getNode('root', 'user');
my $E2 = $DB->getNodeById($e2node_id, 'force');
$DB->insertIntoNodegroup($E2, $root, $wuA);
$DB->insertIntoNodegroup($E2, $root, $wuB);

# force-reload from the nodegroup table so NODEDATA->{group} reflects both writeups
$DB->getNodeById($e2node_id, 'force');
my $e2_fresh = $APP->node_by_id($e2node_id);
is(scalar(@{ $e2_fresh->NODEDATA->{group} || [] }), 2, 'e2node group has both writeups');

# --- e2node bookmark -> BOTH authors notified ("the entire node ...") ---
my $beA = eddie_msgs_to($authorA->{node_id}, 'the entire node');
my $beB = eddie_msgs_to($authorB->{node_id}, 'the entire node');
$api->_notify_bookmark($e2_fresh, $APP->node_by_id($bookmarker->{node_id}));
is(eddie_msgs_to($authorA->{node_id}, 'the entire node'), $beA + 1, 'e2node bookmark notifies author A');
is(eddie_msgs_to($authorB->{node_id}, 'the entire node'), $beB + 1, 'e2node bookmark notifies author B');

# --- single writeup bookmark -> only that writeup's author ("your writeup ...") ---
my $bwA = eddie_msgs_to($authorA->{node_id}, 'your writeup');
my $bwB = eddie_msgs_to($authorB->{node_id}, 'your writeup');
$api->_notify_bookmark($APP->node_by_id($wuA), $APP->node_by_id($bookmarker->{node_id}));
is(eddie_msgs_to($authorA->{node_id}, 'your writeup'), $bwA + 1, 'writeup bookmark notifies its author');
is(eddie_msgs_to($authorB->{node_id}, 'your writeup'), $bwB,     'writeup bookmark does NOT notify the other author');

# --- self-bookmark -> no message ---
my $bself = eddie_msgs_to($authorA->{node_id}, 'your writeup');
$api->_notify_bookmark($APP->node_by_id($wuA), $APP->node_by_id($authorA->{node_id}));
is(eddie_msgs_to($authorA->{node_id}, 'your writeup'), $bself, 'self-bookmark sends no message');

# --- cleanup: messages (text carries $mark via the node title), then nodes ---
$DB->sqlDelete('message', "msgtext LIKE " . $DB->{dbh}->quote("%$mark%"));
$DB->nukeNode($DB->getNodeById($wuA), -1) if $DB->getNodeById($wuA);
$DB->nukeNode($DB->getNodeById($wuB), -1) if $DB->getNodeById($wuB);
$DB->nukeNode($DB->getNodeById($e2node_id), -1) if $DB->getNodeById($e2node_id);

TestSeed::cleanup($DB);

done_testing();
