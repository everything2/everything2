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

# Dedicated sender / recipient / third-user instead of shared singletons
# root / guest user / Cool Man Eddie. Other messaging tests mutate those
# (ignore lists, in_room presence, message rows), which raced this test under
# prove -j4. root stays only as the privileged actor for node ops. #4267
my $root = $DB->getNode('root', 'user');
my $usuffix = 'ign' . $$;
my @created_users;
my $mk_user = sub {
  my ($label) = @_;
  my $uid = $DB->insertNode("e2e_${usuffix}_$label", 'user', $root, undef, 1);
  push @created_users, $uid;
  $DB->sqlDelete('user', "user_id=$uid");   # clean user row (user_id=node_id)
  $DB->sqlInsert('user', { user_id => $uid });
  $DB->getNodeById($uid, 'force');
  return $DB->getNode($uid);
};

my $sender = $mk_user->('sender');
ok($sender, 'Got sender user (dedicated)');

my $recipient = $mk_user->('rcpt');
ok($recipient, 'Got recipient user (dedicated)');

my $eddie = $mk_user->('third');
ok($eddie, 'Got third user (dedicated)');

# Blessed user nodes for deliver_message testing
my $sender_node = $APP->node_by_id($sender->{node_id});
my $recipient_node = $APP->node_by_id($recipient->{node_id});
my $eddie_node = $APP->node_by_id($eddie->{node_id});

# Clear any existing blocks for these users (defensive; they're fresh anyway)
$DB->sqlDelete('messageignore', "messageignore_id IN ($sender->{user_id}, $recipient->{user_id}, $eddie->{user_id})");
$DB->sqlDelete('messageignore', "ignore_node IN ($sender->{user_id}, $recipient->{user_id}, $eddie->{user_id})");

subtest 'User ignoring direct message' => sub {
  plan tests => 5;

  # Ensure no existing ignore
  $DB->sqlDelete('messageignore', "messageignore_id=$recipient->{user_id} AND ignore_node=$sender->{user_id}");

  # Test normal delivery (not ignored)
  my $result = $recipient_node->deliver_message({
    from => $sender_node,
    message => 'Test message before ignore'
  });

  ok($result->{successes}, 'Message delivered when not ignored');
  is($result->{ignores} || 0, 0, 'No ignores reported');

  # Add ignore
  $DB->sqlInsert('messageignore', {
    messageignore_id => $recipient->{user_id},
    ignore_node => $sender->{user_id}
  });

  # Test blocked delivery (ignored)
  $result = $recipient_node->deliver_message({
    from => $sender_node,
    message => 'Test message after ignore'
  });

  ok(!$result->{successes}, 'Message NOT delivered when ignored');
  is($result->{ignores}, 1, 'Ignore reported');

  # Verify message was not inserted
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$recipient->{user_id} AND msgtext='Test message after ignore'"
  );
  is($count, 0, 'Ignored message not inserted into database');

  # Cleanup
  $DB->sqlDelete('messageignore', "messageignore_id=$recipient->{user_id} AND ignore_node=$sender->{user_id}");
  $DB->sqlDelete('message', "msgtext LIKE 'Test message%ignore'");
};

subtest 'User cannot delete other users messages' => sub {
  plan tests => 3;

  # Send a message from sender to recipient
  my $result = $recipient_node->deliver_message({
    from => $sender_node,
    message => 'Test message for delete permission'
  });

  ok($result->{successes}, 'Message delivered successfully');

  # Get the message ID
  my $message_id = $DB->sqlSelect(
    'message_id',
    'message',
    "author_user=$sender->{user_id} AND for_user=$recipient->{user_id} AND msgtext='Test message for delete permission'",
    'LIMIT 1'
  );
  ok($message_id, 'Found message in database');

  # Try to delete as eddie (not the sender or recipient)
  my $delete_count = $DB->sqlDelete(
    'message',
    "message_id=$message_id AND for_user=$eddie->{user_id}"
  );

  # sqlDelete returns '0E0' for zero rows (which evaluates to 0 numerically)
  is(int($delete_count), 0, 'Eddie cannot delete message he is not recipient of');

  # Cleanup
  $DB->sqlDelete('message', "message_id=$message_id");
};

subtest 'User ignoring usergroup messages' => sub {
  plan tests => 6;

  # Create test usergroup
  my $ug_title = 'test_ignore_ug_' . time();
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

  # Add members to usergroup
  $DB->insertIntoNodegroup($ug_node, $root,$sender);
  $DB->insertIntoNodegroup($ug_node, $root,$recipient);
  $DB->insertIntoNodegroup($ug_node, $root,$eddie);

  my $ug_blessed = $APP->node_by_id($ug_node->{node_id});

  # Test normal delivery (not ignored)
  my $result = $ug_blessed->deliver_message({
    from => $sender_node,
    message => 'Usergroup test before ignore'
  });

  ok($result->{successes} >= 2, 'Messages delivered to group members when not ignored');

  # Add ignore for usergroup
  $DB->sqlInsert('messageignore', {
    messageignore_id => $recipient->{user_id},
    ignore_node => $ug_node->{node_id}
  });

  # Clear previous messages
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");

  # Test partial delivery (one user ignoring)
  $result = $ug_blessed->deliver_message({
    from => $sender_node,
    message => 'Usergroup test after ignore'
  });

  # Should deliver to sender and eddie, but NOT to recipient
  is($result->{successes}, 2, 'Messages delivered to non-ignoring members');
  is($result->{ignores}, 0, 'Usergroup ignore is silent (no ignores count)');

  # Verify recipient did NOT receive message
  my $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$recipient->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Usergroup test after ignore'"
  );
  is($count, 0, 'Ignored user did not receive usergroup message');

  # Verify eddie DID receive message
  $count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$eddie->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Usergroup test after ignore'"
  );
  is($count, 1, 'Non-ignored user did receive usergroup message');

  # Cleanup - delete ALL test messages (including to root/eddie)
  $DB->sqlDelete('messageignore', "messageignore_id=$recipient->{user_id} AND ignore_node=$ug_node->{node_id}");
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  # Clean up any messages sent to root
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND msgtext LIKE 'Usergroup test%ignore'");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

subtest 'Usergroup messages preserve for_usergroup field' => sub {
  # Dynamic test count based on number of messages
  # We expect 2 messages (sender + recipient), each tested twice (defined + value match)

  # Create test usergroup
  my $ug_title = 'test_fug_field_' . time();
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

  # Add members
  $DB->insertIntoNodegroup($ug_node, $root,$sender);
  $DB->insertIntoNodegroup($ug_node, $root,$recipient);

  my $ug_blessed = $APP->node_by_id($ug_node->{node_id});

  # Send message to usergroup
  my $result = $ug_blessed->deliver_message({
    from => $sender_node,
    message => 'Testing for_usergroup field'
  });

  ok($result->{successes} >= 2, 'Message sent to usergroup members');

  # Verify all messages have for_usergroup set
  my $csr = $DB->sqlSelectMany(
    'for_user, for_usergroup',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id} AND msgtext='Testing for_usergroup field'"
  );

  my $sender_msg_checked = 0;
  my $recipient_msg_checked = 0;

  while (my ($for_user, $for_usergroup) = $csr->fetchrow_array()) {
    ok(defined($for_usergroup), "for_usergroup is defined for message");
    is($for_usergroup, $ug_node->{node_id}, "for_usergroup matches usergroup node_id");

    $sender_msg_checked = 1 if $for_user == $sender->{user_id};
    $recipient_msg_checked = 1 if $for_user == $recipient->{user_id};
  }

  ok($sender_msg_checked && $recipient_msg_checked, 'Both members received messages');

  # Cleanup - delete ALL test messages (including to root/recipient)
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND msgtext='Testing for_usergroup field'");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");

  done_testing();
};

subtest 'Non-member cannot send to usergroup' => sub {
  plan tests => 3;

  # Create test usergroup
  my $ug_title = 'test_nonmember_' . time();
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

  # Add only sender as member (not eddie)
  $DB->insertIntoNodegroup($ug_node, $root,$sender);

  my $ug_blessed = $APP->node_by_id($ug_node->{node_id});

  # Try to send as non-member
  my $result = $ug_blessed->deliver_message({
    from => $eddie_node,
    message => 'Non-member message attempt'
  });

  ok($result->{errors}, 'Error reported for non-member send');
  ok($result->{errortext}, 'Error text provided');

  # Cleanup
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

subtest 'Usergroup archive copy creation' => sub {
  plan tests => 5;

  # Create test usergroup
  my $ug_title = 'test_archive_' . time();
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

  # Add members
  $DB->insertIntoNodegroup($ug_node, $root,$sender);
  $DB->insertIntoNodegroup($ug_node, $root,$recipient);

  # Enable archive for usergroup
  $APP->setParameter($ug_node, $root, 'allow_message_archive', 1);

  my $ug_blessed = $APP->node_by_id($ug_node->{node_id});

  # Send message
  my $result = $ug_blessed->deliver_message({
    from => $sender_node,
    message => 'Testing archive copy'
  });

  ok($result->{successes} >= 2, 'Message sent to members');

  # Check for archive copy (for_user = usergroup node_id)
  my $archive_count = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_user=$ug_node->{node_id} AND for_usergroup=$ug_node->{node_id}"
  );
  is($archive_count, 1, 'Archive copy created for usergroup');

  # Total messages should be members + 1 archive
  my $total = $DB->sqlSelect(
    'COUNT(*)',
    'message',
    "author_user=$sender->{user_id} AND for_usergroup=$ug_node->{node_id}"
  );
  is($total, 3, 'Total messages includes member messages plus archive');

  # Verify archive message text
  my $archive_text = $DB->sqlSelect(
    'msgtext',
    'message',
    "author_user=$sender->{user_id} AND for_user=$ug_node->{node_id} AND for_usergroup=$ug_node->{node_id}",
    'LIMIT 1'
  );
  is($archive_text, 'Testing archive copy', 'Archive message has correct text');

  # Cleanup - delete ALL test messages (including to root/recipient)
  $DB->sqlDelete('message', "for_usergroup=$ug_node->{node_id}");
  $DB->sqlDelete('message', "author_user=$sender->{user_id} AND msgtext='Testing archive copy'");
  $DB->sqlDelete('nodegroup', "node_id=$ug_node->{node_id}");
  $DB->sqlDelete('node', "node_id=$ug_node->{node_id}");
};

# Final cleanup: remove ignore blocks + nuke the dedicated users (skip_maintenance
# avoids firing user_delete with an unset global USER).
$DB->sqlDelete('messageignore', "messageignore_id IN ($sender->{user_id}, $recipient->{user_id}, $eddie->{user_id})");
$DB->sqlDelete('messageignore', "ignore_node IN ($sender->{user_id}, $recipient->{user_id}, $eddie->{user_id})");
for my $uid (@created_users) {
  my $n = $DB->getNodeById($uid, 'force');
  $DB->nukeNode($n, -1, 0, 1) if $n;
  $DB->sqlDelete('user', "user_id=$uid");
  $DB->sqlDelete('message', "for_user=$uid OR author_user=$uid");
}

done_testing();
