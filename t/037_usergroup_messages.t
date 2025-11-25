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

# Get test users
my $sender = $DB->getNode('root', 'user');
ok($sender, 'Got sender user');

my $guest = $DB->getNode('guest user', 'user');
ok($guest, 'Got guest user');

# Find or create Eddie as non-member
my $non_member = $DB->getNode('Cool Man Eddie', 'user');
ok($non_member, 'Got non-member user');

# Create test usergroup
my $ug_title = 'test_msg_ug_' . time();
my $ug_node = $DB->insertNode(
  $ug_title,
  'usergroup',
  $sender,
  {
    title => $ug_title,
    groupaccess => 'public'
  }
);
ok($ug_node, 'Created test usergroup');

# Add members to usergroup (NODE, USER_authorizing, node_to_add)
$DB->insertIntoNodegroup($ug_node, $sender, $sender);
$DB->insertIntoNodegroup($ug_node, $sender, $guest);

subtest 'Send message to usergroup as member' => sub {
  plan tests => 7;

  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Test message to usergroup'
  );

  ok($result->{success}, 'Message sent successfully');
  cmp_ok(scalar @{$result->{sent_to}}, '==', 2, 'Sent to 2 users (all members)');

  # Check messages were created in database
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  cmp_ok($count, '==', 2, 'Two messages created in database');

  # Verify message text
  my $msg = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_user=$guest->{user_id} AND for_usergroup=$ug_node->{node_id}",
    'LIMIT 1'
  );
  is($msg, 'Test message to usergroup', 'Message text is correct');

  # Verify for_usergroup field is set correctly (not undef)
  my $ug_id = $DB->sqlSelect(
    'for_usergroup',
    'message',
    "author_user=$sender->{user_id} AND for_user=$guest->{user_id} AND for_usergroup=$ug_node->{node_id}",
    'LIMIT 1'
  );
  cmp_ok($ug_id, '==', $ug_node->{node_id}, 'for_usergroup field set to node_id (not user_id)');
  ok(defined($ug_id), 'for_usergroup is defined (not undef)');
  ok($ug_id > 0, 'for_usergroup is positive integer');
};

subtest 'Non-member cannot send to usergroup' => sub {
  plan tests => 2;

  my $result = $APP->sendPrivateMessage(
    $non_member,
    [$ug_title],
    'Unauthorized message'
  );

  ok(!$result->{success}, 'Message rejected for non-member');
  like(join(' ', @{$result->{errors}}), qr/You are not a member/i, 'Error message indicates non-membership');
};

subtest 'Message usergroup via /msg command' => sub {
  plan tests => 3;

  # Clear previous messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}");

  my $vars = $APP->getVars($sender);
  my $success = $APP->processMessageCommand(
    $sender,
    "/msg $ug_title Hello everyone!",
    $vars
  );

  ok($success, 'Command processed successfully');

  # Check messages were created
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  cmp_ok($count, '==', 2, 'Two messages created via command');

  # Verify message text
  my $msg = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}",
    'LIMIT 1'
  );
  is($msg, 'Hello everyone!', 'Message text is correct');
};

subtest 'Usergroup archive copy' => sub {
  plan tests => 3;

  # Clear previous messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}");

  # Enable archive for usergroup
  $APP->setParameter($ug_node, $sender, 'allow_message_archive', 1);

  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Archived message'
  );

  ok($result->{success}, 'Message sent successfully');

  # Check for archive copy (for_user = usergroup node_id)
  my $archive_count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$ug_node->{node_id} AND for_usergroup=$ug_node->{node_id}"
  );
  cmp_ok($archive_count, '==', 1, 'Archive copy created for usergroup');

  # Total messages should be 3 (2 members + 1 archive)
  my $total = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  cmp_ok($total, '==', 3, 'Total messages includes archive copy');
};

subtest 'Nested usergroup message delivery' => sub {
  plan tests => 5;

  # Test with real nested groups: Content Editors contains e2gods contains root
  my $content_editors = $DB->getNode('Content Editors', 'usergroup');
  ok($content_editors, 'Got Content Editors usergroup');

  my $e2gods = $DB->getNode('e2gods', 'usergroup');
  ok($e2gods, 'Got e2gods usergroup');

  # Clear previous messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}");

  # Send message to Content Editors as root (who is in e2gods, which is in Content Editors)
  my $result = $APP->sendPrivateMessage(
    $sender,
    ['Content Editors'],
    'Test nested delivery'
  );

  ok($result->{success}, 'Message sent successfully to nested usergroup');

  # Check that root received the message (even though root is only in e2gods, not directly in Content Editors)
  my $root_message_count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}"
  );
  cmp_ok($root_message_count, '==', 1, 'Root received message via nested usergroup (e2gods)');

  # Check total messages - should include all expanded members
  # Content Editors members: e2gods (contains root) + genericeditor = 2 users total
  my $total = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}"
  );
  cmp_ok($total, '>=', 2, 'Messages delivered to all expanded usergroup members');

  # Cleanup nested usergroup test messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}");
};

subtest 'Message forwarding (chatterbox forward)' => sub {
  plan tests => 6;

  # Test c_e user which forwards to Content Editors
  my $c_e = $DB->getNode('c_e', 'user');
  ok($c_e, 'Got c_e user');

  # Verify forward is set up
  ok($c_e->{message_forward_to}, 'c_e has message_forward_to set');

  my $content_editors = $DB->getNode('Content Editors', 'usergroup');
  is($c_e->{message_forward_to}, $content_editors->{node_id}, 'c_e forwards to Content Editors');

  # Clear previous messages
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}");

  # Send message to c_e - should be forwarded to Content Editors usergroup
  my $result = $APP->sendPrivateMessage(
    $sender,
    ['c_e'],
    'Test message forwarding'
  );

  ok($result->{success}, 'Message sent successfully to c_e');

  # Check that message was delivered to Content Editors members (via forwarding)
  # Content Editors contains: e2gods (which contains root) + genericeditor
  my $total = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}"
  );
  cmp_ok($total, '>=', 2, 'Messages delivered to Content Editors members via c_e forward');

  # Verify root received the forwarded message
  my $root_msg = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}"
  );
  cmp_ok($root_msg, '==', 1, 'Root received forwarded message');

  # Cleanup
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND for_usergroup=$content_editors->{node_id}");
};

# Cleanup test usergroup
$DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
$DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
$DB->sqlDelete('node', "node_id=$ug_node->{node_id}");

# Reset root user to "outside" room and rebuild otherusers cache
$DB->sqlUpdate('user', { in_room => 0 }, "user_id=$sender->{user_id}");
my $otherusers_data = $APP->buildOtherUsersData($sender);
$DB->stashData('otherusers', $otherusers_data);

done_testing();
