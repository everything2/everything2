#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 225_notify_new_comment.t
#
# Everything::Application::notify_new_comment -- the per-member "newcomment"
# notification for a new reply in a usergroup discussion (#4661). It replaced the
# debatecomment_create maintenance hook's block, which never delivered anything.
#
# Verifies: opted-in members are notified; opted-out / no-pref members and the
# replier are NOT; the returned count matches; the stored args render (naming the
# replier and the discussion) and pass the newcomment validity check.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Delegation::notification;
use TestSeed;

initEverything('development-docker');
ok($DB,  'DB connection');
ok($APP, 'APP object');

my $root = $DB->getNode('root', 'user');
my $NC   = $DB->getNode('newcomment', 'notification')->{node_id};
ok($NC, 'newcomment notification exists');

sub set_notif_pref {
    my ($u, $val) = @_;   # $val: 0/1, or undef to leave notifications absent
    my $node = $DB->getNodeById($u->{node_id}, 'force');
    my $vars = $APP->getVars($node);
    my $settings = ($vars->{settings} && $vars->{settings} =~ /\{/) ? eval { from_json($vars->{settings}) } : {};
    $settings = {} unless ref $settings eq 'HASH';
    $settings->{notifications}{$NC} = $val if defined $val;
    $vars->{settings} = to_json($settings);
    Everything::setVars($node, $vars);
    return;
}
sub notified_count {
    my ($u) = @_;
    return $DB->sqlSelect('COUNT(*)', 'notified', "notification_id=$NC AND user_id=$u->{node_id}");
}

# --- a usergroup with a spread of members, and a discussion with one reply ------
my $replier = TestSeed::make_user($DB, $APP, label => 'nc-replier');
my $optin   = TestSeed::make_user($DB, $APP, label => 'nc-optin');
my $optout  = TestSeed::make_user($DB, $APP, label => 'nc-optout');
my $nopref  = TestSeed::make_user($DB, $APP, label => 'nc-nopref');

my $ug_id = $DB->insertNode('NCNotifyUG ' . time(), 'usergroup', $root, {});
my $ug    = $DB->getNodeById($ug_id, 'force');
$DB->insertIntoNodegroup($ug, $root, $_->{node_id}) for ($replier, $optin, $optout, $nopref);
$DB->updateNode($ug, $root);

set_notif_pref($optin,  1);
set_notif_pref($optout, 0);
set_notif_pref($nopref, undef);

my $debate_title = 'NC discussion ' . time();
my $debate_id = $DB->insertNode($debate_title, 'debate', $root,
    { doctext => 'topic', parent_debatecomment => 0, restricted => $ug_id }, 1);
my $debate = $DB->getNodeById($debate_id, 'force');
$debate->{root_debatecomment} = $debate_id;
$DB->updateNode($debate, $root, undef, 1);

my $reply_id = $DB->insertNode('re: ' . $debate_title, 'debatecomment', $DB->getNodeById($replier->{node_id}),
    { doctext => 'a reply', parent_debatecomment => $debate_id, root_debatecomment => $debate_id,
      restricted => $ug_id }, 1);
ok($debate_id && $reply_id, 'created a discussion and a reply');

# --- the call ------------------------------------------------------------------
my $sent = $APP->notify_new_comment($replier->{node_id}, $reply_id);

ok(notified_count($optin),     'opted-in member WAS notified');
is(notified_count($optout), 0, 'opted-out member (pref=0) was NOT notified');
is(notified_count($nopref), 0, 'member without the newcomment pref was NOT notified');
is(notified_count($replier), 0,'the replier was NOT notified');
is($sent, 1, 'notify_new_comment reports exactly one notification sent');

# The stored args render and validate with the newcomment delegation.
my $args_json = $DB->sqlSelect('args', 'notified', "notification_id=$NC AND user_id=$optin->{node_id}");
my $args = from_json($args_json);
is($args->{node_id}, $reply_id, 'args carry the reply as node_id');
is($args->{root}, $debate_id, 'args carry the discussion as root');
my $text = Everything::Delegation::notification::newcomment($DB, $APP, $args);
like($text, qr/^\[\Q$replier->{title}\E\] replied in \[\Q$debate_title\E\]$/, 'renders who replied and in which discussion');
ok(Everything::Delegation::notification::newcomment_is_valid($DB, $APP, $args), 'passes the newcomment validity check');

# A reply that's gone no longer shows.
ok(!Everything::Delegation::notification::newcomment_is_valid($DB, $APP, { node_id => 0 }), 'missing reply is not valid');

# Nothing to do for a reply without a usergroup.
is($APP->notify_new_comment($replier->{node_id}, 0), 0, 'no reply: nothing sent');

# --- cleanup -------------------------------------------------------------------
$DB->sqlDelete('notified', "notification_id=$NC AND user_id IN ($optin->{node_id},$optout->{node_id},$nopref->{node_id},$replier->{node_id})");
for my $id ($reply_id, $debate_id, $ug_id) {
    my $n = $DB->getNodeById($id, 'force');
    $DB->nukeNode($n, -1, 1, 1) if $n;
}
TestSeed::cleanup($DB);

done_testing();
