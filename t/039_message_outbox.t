#!/usr/bin/perl -w

use strict;
use utf8;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use TestSeed;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Suppress expected warnings
$SIG{__WARN__} = sub {
    my $warning = shift;
    warn $warning unless $warning =~ /Could not open log/
                      || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

# Test users
# Dedicated sender/recipient instead of shared root / Cool Man Eddie (their
# message + outbox rows are read/wiped by other tests; raced under -j4). #4267
my $sender = TestSeed::make_user($DB, $APP, label => 'sender');
my $recipient = TestSeed::make_user($DB, $APP, label => 'recipient');

ok($sender, 'Got sender user (dedicated)');
ok($recipient, 'Got recipient user (dedicated)');

# Clean up any existing messages for these users
$DB->sqlDelete('message', "for_user=$sender->{user_id} OR for_user=$recipient->{user_id}");
$DB->sqlDelete('message_outbox', "author_user=$sender->{user_id}");

subtest 'Private message creates inbox and outbox entries' => sub {
    plan tests => 7;

    # Send a private message
    my $result = $APP->sendPrivateMessage(
        $sender,
        [$recipient->{title}],
        'Test message for outbox',
        {}
    );

    ok($result->{success}, 'Message sent successfully');
    is(scalar(@{$result->{sent_to}}), 1, 'Message sent to one recipient');
    is($result->{sent_to}[0], $recipient->{title}, 'Sent to correct recipient');

    # Check inbox message (for recipient)
    my $inbox_msg = $DB->sqlSelectHashref(
        '*',
        'message',
        "for_user=$recipient->{user_id} AND author_user=$sender->{user_id}"
    );
    ok($inbox_msg, 'Inbox message created for recipient');
    is($inbox_msg->{msgtext}, 'Test message for outbox', 'Inbox message has correct text');

    # Check outbox message (for sender) in message_outbox table
    my $outbox_msg = $DB->sqlSelectHashref(
        '*',
        'message_outbox',
        "author_user=$sender->{user_id}"
    );
    ok($outbox_msg, 'Outbox message created for sender');
    is($outbox_msg->{msgtext}, 'Test message for outbox', 'Outbox message has correct text');
};

subtest 'Multiple recipients create multiple outbox entries' => sub {
    plan tests => 5;

    # Clean up
    my $recipient2 = TestSeed::make_user($DB, $APP, label => 'recipient2');
    ok($recipient2, 'Got second recipient');

    $DB->sqlDelete('message', "for_user=$sender->{user_id} OR for_user=$recipient->{user_id} OR for_user=$recipient2->{user_id}");
    $DB->sqlDelete('message_outbox', "author_user=$sender->{user_id}");

    # Send to multiple recipients
    my $result = $APP->sendPrivateMessage(
        $sender,
        [$recipient->{title}, $recipient2->{title}],
        'Multi-recipient test',
        {}
    );

    ok($result->{success}, 'Multi-recipient message sent successfully');
    is(scalar(@{$result->{sent_to}}), 2, 'Message sent to two recipients');

    # Count outbox messages in message_outbox table
    # Note: Legacy behavior creates ONE outbox entry per message sent, not per recipient
    my $outbox_count = $DB->sqlSelect(
        'COUNT(*)',
        'message_outbox',
        "author_user=$sender->{user_id}"
    );
    is($outbox_count, 2, 'Two outbox messages created for sender (one per recipient)');

    # Verify messages exist and have the expected text
    my @outbox_texts = $DB->sqlSelect(
        'msgtext',
        'message_outbox',
        "author_user=$sender->{user_id}"
    );
    # Should get first message's text, verify it matches expected
    is($outbox_texts[0], 'Multi-recipient test', 'Outbox messages have correct text');
};

subtest 'Online-only messages create outbox with OnO prefix' => sub {
    plan tests => 4;

    # Clean up
    $DB->sqlDelete('message', "for_user=$sender->{user_id} OR for_user=$recipient->{user_id}");
    $DB->sqlDelete('message_outbox', "author_user=$sender->{user_id}");

    # Set recipient to accept offline ONO messages
    my $recip_vars = $APP->getVars($recipient);
    $recip_vars->{getofflinemsgs} = 1;
    Everything::setVars($recipient, $recip_vars);

    # Send online-only message
    my $result = $APP->sendPrivateMessage(
        $sender,
        [$recipient->{title}],
        'Online-only test',
        { online_only => 1 }
    );

    ok($result->{success}, 'Online-only message sent successfully');
    is(scalar(@{$result->{sent_to}}), 1, 'Message sent to recipient');

    # Check outbox message has OnO prefix in message_outbox table
    my $outbox_msgtext = $DB->sqlSelect(
        'msgtext',
        'message_outbox',
        "author_user=$sender->{user_id}"
    );
    ok($outbox_msgtext, 'Outbox message created');
    like($outbox_msgtext, qr/^OnO:/xms, 'Outbox message has OnO prefix');
};

subtest '/msg command via chatter API creates outbox' => sub {
    plan tests => 5;

    # Clean up
    $DB->sqlDelete('message', "for_user=$sender->{user_id} OR for_user=$recipient->{user_id}");
    $DB->sqlDelete('message_outbox', "author_user=$sender->{user_id}");

    # Get sender VARS
    my $vars = $APP->getVars($sender);

    # The dedicated title is hyphenated (no underscores), so /msg addresses it
    # directly as a single token without the _->space mangling.
    my $result = $APP->processMessageCommand(
        $sender,
        "/msg $recipient->{title} Test via chatter API",
        $vars
    );

    ok($result, '/msg command processed successfully');

    # Check inbox message
    my $inbox_msg = $DB->sqlSelectHashref(
        '*',
        'message',
        "for_user=$recipient->{user_id} AND author_user=$sender->{user_id}"
    );
    ok($inbox_msg, 'Inbox message created via /msg command');
    is($inbox_msg->{msgtext}, 'Test via chatter API', 'Inbox message has correct text');

    # Check outbox message in message_outbox table
    my $outbox_msg = $DB->sqlSelectHashref(
        '*',
        'message_outbox',
        "author_user=$sender->{user_id}"
    );
    ok($outbox_msg, 'Outbox message created via /msg command');
    is($outbox_msg->{msgtext}, $inbox_msg->{msgtext}, 'Inbox and outbox have same message text');
};

# Clean up
$DB->sqlDelete('message', "for_user=$sender->{user_id} OR for_user=$recipient->{user_id}");
$DB->sqlDelete('message_outbox', "author_user=$sender->{user_id}");

TestSeed::cleanup($DB);

done_testing();
