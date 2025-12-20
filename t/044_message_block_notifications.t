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

my $blocker = $DB->getNode('guest user', 'user');
ok($blocker, 'Got blocker user');

my $eddie = $DB->getNode('Cool Man Eddie', 'user');
ok($eddie, 'Got third user (Eddie)');

subtest 'Direct message blocking returns error notification' => sub {
  plan tests => 7;

  # Ensure no existing ignore
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");

  # Test normal delivery (not blocked)
  my $result = $APP->sendPrivateMessage(
    $sender,
    [$blocker->{title}],
    'Test message before block'
  );

  ok($result->{success}, 'Message delivered when not blocked');
  is(scalar(@{$result->{sent_to} || []}), 1, 'Message sent to one recipient');
  ok(!$result->{errors}, 'No errors when not blocked');

  # Add block
  $DB->sqlInsert('messageignore', {
    messageignore_id => $blocker->{user_id},
    ignore_node => $sender->{user_id}
  });

  # Test blocked delivery - should return error
  $result = $APP->sendPrivateMessage(
    $sender,
    [$blocker->{title}],
    'Test message after block'
  );

  ok(!$result->{success}, 'Message NOT sent when blocked');
  is(scalar(@{$result->{sent_to} || []}), 0, 'No recipients for blocked message');
  ok($result->{errors}, 'Errors array returned for blocked message');
  like($result->{errors}[0], qr/is ignoring you/, 'Error message indicates blocking');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('message', "msgtext LIKE 'Test message%block'");
};

subtest 'Usergroup message with individual blocker returns notification' => sub {
  plan tests => 10;

  # Create test usergroup
  my $ug_title = 'test_block_notify_' . time();
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

  # Add members to usergroup
  $DB->insertIntoNodegroup($ug_node, $sender, $sender);
  $DB->insertIntoNodegroup($ug_node, $sender, $blocker);
  $DB->insertIntoNodegroup($ug_node, $sender, $eddie);

  # Test normal delivery (no blocks)
  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Test usergroup message before block'
  );

  ok($result->{success}, 'Usergroup message sent when not blocked');
  is(scalar(@{$result->{sent_to} || []}), 3, 'Message sent to all three members');

  # Add block for sender from blocker user
  $DB->sqlInsert('messageignore', {
    messageignore_id => $blocker->{user_id},
    ignore_node => $sender->{user_id}
  });

  # Clear previous messages
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");

  # Test delivery with one member blocking
  $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Test usergroup message after block'
  );

  ok($result->{success}, 'Usergroup message still sent to unblocked members');
  is(scalar(@{$result->{sent_to} || []}), 2, 'Message sent to two unblocked members');
  ok($result->{errors}, 'Errors array returned for blocked member');
  is(scalar(@{$result->{errors} || []}), 1, 'One error for blocked member');
  like($result->{errors}[0], qr/is ignoring you/, 'Error message indicates blocking');

  # Verify blocker did NOT receive message
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$blocker->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Test usergroup message after block'"
  );
  is($count, 0, 'Blocked user did not receive usergroup message');

  # Verify eddie DID receive message
  $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$eddie->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Test usergroup message after block'"
  );
  is($count, 1, 'Unblocked user did receive usergroup message');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND msgtext LIKE 'Test usergroup message%block'");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

subtest 'handlePrivateMessageCommand returns error for blocked user' => sub {
  plan tests => 6;

  # Ensure no existing ignore
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");

  # Get VARS for sender
  my $vars = $APP->getVars($sender);

  # Use underscores for username with spaces (as required by /msg command)
  my $blocker_cmd_name = $blocker->{title};
  $blocker_cmd_name =~ s/ /_/g;

  # Test normal message (not blocked)
  my $result = $APP->handlePrivateMessageCommand(
    $sender,
    "$blocker_cmd_name Test direct message before block",
    $vars
  );

  ok($result, 'handlePrivateMessageCommand returns result');
  ok($result->{success}, 'Command successful when not blocked');

  # Add block
  $DB->sqlInsert('messageignore', {
    messageignore_id => $blocker->{user_id},
    ignore_node => $sender->{user_id}
  });

  # Test blocked message
  $result = $APP->handlePrivateMessageCommand(
    $sender,
    "$blocker_cmd_name Test direct message after block",
    $vars
  );

  ok($result, 'handlePrivateMessageCommand returns result for blocked');
  ok(!$result->{success}, 'Command fails when blocked');
  ok($result->{error}, 'Error message returned');
  like($result->{error}, qr/is ignoring you/, 'Error indicates blocking');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('message', "msgtext LIKE 'Test direct message%block'");
};

subtest 'Multiple blockers in usergroup return multiple errors' => sub {
  plan tests => 8;

  # Create test usergroup
  my $ug_title = 'test_multi_block_' . time();
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

  # Add members to usergroup
  $DB->insertIntoNodegroup($ug_node, $sender, $sender);
  $DB->insertIntoNodegroup($ug_node, $sender, $blocker);
  $DB->insertIntoNodegroup($ug_node, $sender, $eddie);

  # Add blocks from both blocker and eddie
  $DB->sqlInsert('messageignore', {
    messageignore_id => $blocker->{user_id},
    ignore_node => $sender->{user_id}
  });
  $DB->sqlInsert('messageignore', {
    messageignore_id => $eddie->{user_id},
    ignore_node => $sender->{user_id}
  });

  # Test delivery with two members blocking
  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Test message with multiple blocks'
  );

  ok($result->{success}, 'Usergroup message still sent to sender');
  is(scalar(@{$result->{sent_to} || []}), 1, 'Message only sent to sender (not blocked members)');
  ok($result->{errors}, 'Errors array returned for blocked members');
  is(scalar(@{$result->{errors} || []}), 2, 'Two errors for two blocked members');

  # Check both errors mention blocking
  my $error_text = join(' ', @{$result->{errors}});
  like($error_text, qr/is ignoring you/, 'Error messages indicate blocking');

  # Verify neither blocker nor eddie received message
  my $blocker_count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$blocker->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  is($blocker_count, 0, 'First blocked user did not receive message');

  my $eddie_count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$eddie->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  is($eddie_count, 0, 'Second blocked user did not receive message');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('messageignore', "messageignore_id=$eddie->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

subtest 'Usergroup block does not trigger individual block notification' => sub {
  plan tests => 5;

  # Create test usergroup
  my $ug_title = 'test_ug_block_' . time();
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

  # Add members
  $DB->insertIntoNodegroup($ug_node, $sender, $sender);
  $DB->insertIntoNodegroup($ug_node, $sender, $blocker);
  $DB->insertIntoNodegroup($ug_node, $sender, $eddie);

  # Add block for usergroup itself (not sender)
  $DB->sqlInsert('messageignore', {
    messageignore_id => $blocker->{user_id},
    ignore_node => $ug_node->{node_id}
  });

  # Test delivery
  my $result = $APP->sendPrivateMessage(
    $sender,
    [$ug_title],
    'Test usergroup block vs individual block'
  );

  ok($result->{success}, 'Usergroup message sent');
  is(scalar(@{$result->{sent_to} || []}), 2, 'Message sent to sender and eddie (not blocker)');

  # No individual block errors should be returned (usergroup blocks are silent)
  ok(!$result->{errors} || scalar(@{$result->{errors}}) == 0, 'No individual block errors for usergroup block');

  # Verify blocker did not receive message
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$blocker->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  is($count, 0, 'User blocking usergroup did not receive message');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$blocker->{user_id} AND ignore_node=$ug_node->{node_id}");
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

# Reset root user to "outside" room
$DB->sqlUpdate('user', { in_room => 0 }, "user_id=$sender->{user_id}");

done_testing();
