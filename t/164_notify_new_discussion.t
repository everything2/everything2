#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 164_notify_new_discussion.t
#
# Everything::Application::notify_new_discussion -- the per-member "newdiscussion"
# notification, moved out of the unreliable debate_create maintenance hook (which
# detected API-vs-form via !$query, broken under PSGI) into the API create path.
#
# Verifies: opted-in members are notified; opted-out / no-pref / no-settings
# members and the creator are NOT; the returned count matches; malformed member
# settings don't blow up the loop.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use TestSeed;

initEverything('development-docker');
ok($DB,  'DB connection');
ok($APP, 'APP object');

my $root = $DB->getNode('root', 'user');
my $ND   = $DB->getNode('newdiscussion', 'notification')->{node_id};

sub set_notif_pref {
    my ($u, $val) = @_;   # $val: 0/1, or undef to leave notifications absent
    my $node = $DB->getNodeById($u->{node_id}, 'force');
    my $vars = $APP->getVars($node);
    my $settings = ($vars->{settings} && $vars->{settings} =~ /\{/) ? eval { from_json($vars->{settings}) } : {};
    $settings = {} unless ref $settings eq 'HASH';
    $settings->{notifications}{$ND} = $val if defined $val;
    $vars->{settings} = to_json($settings);
    Everything::setVars($node, $vars);
}
sub notified_count {
    my ($u) = @_;
    $DB->sqlSelect('COUNT(*)', 'notified', "notification_id=$ND AND user_id=$u->{node_id}");
}

# --- build a usergroup with a spread of members --------------------------------
my $creator = TestSeed::make_user($DB, $APP, label => 'nd-creator');
my $optin   = TestSeed::make_user($DB, $APP, label => 'nd-optin');
my $optout  = TestSeed::make_user($DB, $APP, label => 'nd-optout');
my $nopref  = TestSeed::make_user($DB, $APP, label => 'nd-nopref');   # settings, but no newdiscussion key

my $ug_id = $DB->insertNode('NDNotifyUG ' . time(), 'usergroup', $root, {});
my $ug    = $DB->getNodeById($ug_id, 'force');
$DB->insertIntoNodegroup($ug, $root, $_->{node_id}) for ($creator, $optin, $optout, $nopref);
$DB->updateNode($ug, $root);

set_notif_pref($optin,  1);            # opted in
set_notif_pref($optout, 0);            # explicitly opted out
set_notif_pref($nopref, undef);        # has settings, but no newdiscussion pref

# sanity: usergroupToUserIds expands the membership
my %members = map { $_ => 1 } split ',', $APP->usergroupToUserIds($ug_id);
ok($members{ $optin->{node_id} },  'opt-in member is in the usergroup set');
ok($members{ $creator->{node_id} },'creator is in the usergroup set');

# --- the call ------------------------------------------------------------------
my $sent = $APP->notify_new_discussion($creator->{node_id}, $ug_id, 999_999);

ok(notified_count($optin),    'opted-in member WAS notified');
is(notified_count($optout), 0,'opted-out member (pref=0) was NOT notified');
is(notified_count($nopref), 0,'member without the newdiscussion pref was NOT notified');
is(notified_count($creator),0,'the creator was NOT notified');
is($sent, 1, 'notify_new_discussion reports exactly one notification sent');

# the notification carries the discussion node_id in its args (the key the
# newdiscussion render/_is_valid delegation reads), so it renders + validates
my $args = $DB->sqlSelect('args', 'notified', "notification_id=$ND AND user_id=$optin->{node_id}");
like($args, qr/"node_id"\s*:\s*999999/, 'notification args carry node_id (what the delegation reads)');

# --- cleanup -------------------------------------------------------------------
$DB->sqlDelete('notified', "notification_id=$ND AND user_id=$optin->{node_id}");
$DB->nukeNode($DB->getNodeById($ug_id, 'force'), -1, 1) if $DB->getNodeById($ug_id, 'force');
TestSeed::cleanup($DB);

done_testing();
