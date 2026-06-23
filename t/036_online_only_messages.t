#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");

# Dedicated sender + recipients instead of the shared singletons root / guest
# user / Cool Man Eddie. Those are mutated by other messaging tests (ignore
# lists, delivery prefs, presence), which raced this test's delivery counts
# under prove -j4. Throwaway users created here, nuked in teardown. #4267
my $root = $DB->getNode('root', 'user');
my $usuffix = 'ono' . $$;
my @created_users;
my $mk_user = sub {
  my ($label) = @_;
  my $uid = $DB->insertNode("e2e_${usuffix}_$label", 'user', $root, undef, 1);
  push @created_users, $uid;
  $DB->sqlDelete('user', "user_id=$uid");   # ensure a clean user row (user_id=node_id)
  $DB->sqlInsert('user', { user_id => $uid });
  # Mark "online" (a room row) so online_only delivery reaches them. Scoping
  # presence to our own throwaway users is the whole point -- no shared singleton.
  $DB->sqlInsert('room', { member_user => $uid });
  $DB->getNodeById($uid, 'force');
  return $DB->getNode($uid);
};

my $sender = $mk_user->('sender');
ok($sender, 'Got sender user (dedicated)');

my $recipient1 = $mk_user->('rcpt1');
ok($recipient1, 'Got recipient 1 (dedicated)');

my $recipient2 = $mk_user->('rcpt2');
ok($recipient2, 'Got recipient 2 (dedicated)');

# Create test usergroup
my $ug_title = 'test_ono_msg_ug_' . time();
my $ug_node = $DB->insertNode(
  $ug_title,
  'usergroup',
  $root,
  {
    title => $ug_title,
    groupaccess => 'public'
  }
);
ok($ug_node, 'Created test usergroup');

# Add members to usergroup (root is the privileged actor; members are the
# dedicated users so message delivery doesn't touch shared singletons)
$DB->insertIntoNodegroup($ug_node, $root, $sender);
$DB->insertIntoNodegroup($ug_node, $root, $recipient1);
$DB->insertIntoNodegroup($ug_node, $root, $recipient2);

subtest 'Send online-only message to usergroup' => sub {
  plan tests => 8;

  # Send online-only message (uses online_only option)
  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'OnO test message',
    { online_only => 1 }
  );

  ok($result->{success}, 'Online-only message sent successfully');
  ok(scalar @{$result->{sent_to}} > 0, 'Message sent to at least one recipient');

  # Check messages were created with online-only flag
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext LIKE '%OnO test message%'"
  );
  ok($count > 0, 'At least one online-only message created in database');

  # Verify message text includes "OnO: " prefix
  my $msg = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}",
    'ORDER BY message_id DESC LIMIT 1'
  );
  like($msg, qr/^OnO:/, 'Message text includes "OnO: " prefix');

  # Check that offline users with getofflinemsgs=1 still receive message
  # (This would require setting up VARS for test users - skipped for basic test)

  # Verify for_usergroup field is set correctly
  my $ug_id = $DB->sqlSelect(
    'for_usergroup',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}",
    'ORDER BY message_id DESC LIMIT 1'
  );
  cmp_ok($ug_id, '==', $ug_node->{node_id}, 'for_usergroup field set correctly');
  ok(defined($ug_id), 'for_usergroup is defined');
  ok($ug_id > 0, 'for_usergroup is positive integer');

  # Cleanup - delete test messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}");
  ok(1, 'Cleaned up test messages');
};

subtest 'Normal message vs online-only message difference' => sub {
  plan tests => 6;

  # Send normal message
  my $normal_result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Normal test message',
    { online_only => 0 }
  );

  ok($normal_result->{success}, 'Normal message sent successfully');
  cmp_ok(scalar @{$normal_result->{sent_to}}, '==', 3, 'Normal message sent to all 3 members');

  # Verify normal message does NOT have "OnO: " prefix
  my $normal_msg = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Normal test message'",
    'LIMIT 1'
  );
  unlike($normal_msg, qr/^OnO:/, 'Normal message does NOT have "OnO: " prefix');

  # Send online-only message
  my $ono_result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'OnO comparison test',
    { online_only => 1 }
  );

  ok($ono_result->{success}, 'Online-only message sent successfully');

  # Verify online-only message DOES have "OnO: " prefix
  my $ono_msg = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext LIKE 'OnO:%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  like($ono_msg, qr/^OnO:/, 'Online-only message has "OnO: " prefix');

  # Cleanup
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}");
  ok(1, 'Cleaned up test messages');
};

# Cleanup test usergroup + the dedicated users (skip_maintenance avoids firing
# user_delete on a teardown where the global USER isn't set).
$DB->nukeNode($ug_node, $root);
for my $uid (@created_users) {
  my $n = $DB->getNodeById($uid, 'force');
  $DB->nukeNode($n, -1, 0, 1) if $n;
  $DB->sqlDelete('user', "user_id=$uid");
  $DB->sqlDelete('room', "member_user=$uid");
}

done_testing();
