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

# Use existing users for testing
my $user1 = $DB->getNode('root', 'user');
my $user2 = $DB->getNode('guest user', 'user');
my $user3 = $DB->getNode('Cool Man Eddie', 'user');

# Get an existing usergroup for testing
my $test_group = $DB->getNode('gods', 'usergroup');

# Mock Query Object
package MockQuery;
sub new {
	my ($class, $params) = @_;
	return bless { params => $params || {} }, $class;
}
sub param {
	my ($self, $name, $value) = @_;
	if (defined $value) {
		$self->{params}{$name} = $value;
	}
	if (!defined $name) {
		return keys %{$self->{params}};
	}
	return $self->{params}{$name};
}

# Helper to send message via opcode
package main;

sub send_message {
	my ($user, $params) = @_;
	my $query = MockQuery->new($params);
	my $NODE = $DB->getNode('root', 'user');
	my $VARS = Everything::getVars($user);

	# Ensure publicchatteroff is not set for tests (allows public chatter)
	delete $VARS->{publicchatteroff};

	require Everything::Delegation::opcode;
	return Everything::Delegation::opcode::message(
		$DB, $query, $NODE, $user, $VARS, $APP
	);
}

subtest 'Public chatter - basic functionality' => sub {
	plan tests => 4;

	# Clear existing messages
	$DB->sqlDelete('message', 'for_user=0');

	# Send a simple public message
	send_message($user1, {
		message => 'Hello world test message',
		sendto => 0
	});

	# Verify message was inserted
	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $user1->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, 'Public message was inserted');
	is($msg->{msgtext}, 'Hello world test message', 'Message text is correct');
	is($msg->{author_user}, $user1->{node_id}, 'Author is correct');
	is($msg->{for_user}, 0, 'for_user is 0 for public');
};

subtest 'Public chatter - 512 character limit' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	# Very long message should be truncated
	my $long_msg = 'x' x 600;
	send_message($user1, {
		message => $long_msg,
		sendto => 0
	});

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $user1->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, 'Long message was inserted');
	is(length($msg->{msgtext}), 512, 'Message was truncated to 512 chars');
};

subtest 'Private messages - basic functionality' => sub {
	plan tests => 3;

	# Test that private messages can be created directly (not via /msg which requires more setup)
	$DB->sqlDelete('message', 'for_user > 0');

	$DB->sqlInsert('message', {
		msgtext => 'Direct PM test',
		author_user => $user1->{node_id},
		for_user => $user3->{node_id}
	});

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'for_user=' . $user3->{node_id},
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, 'Private message was created');
	is($msg->{msgtext}, 'Direct PM test', 'Message text is correct');
	is($msg->{for_user}, $user3->{node_id}, 'Recipient is correct');
};

subtest 'Special commands - /roll dice' => sub {
	plan tests => 3;

	$DB->sqlDelete('message', 'for_user=0');

	# Simple roll
	send_message($user1, {
		message => '/roll 1d6',
		sendto => 0
	});

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $user1->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, 'Roll message was sent');
	like($msg->{msgtext}, qr/\/rolls 1d6/sm, 'Roll message format is correct');
	like($msg->{msgtext}, qr/(&rarr;|→)/sm, 'Result arrow is present');
};

subtest 'Special commands - /me action' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	send_message($user1, {
		message => '/me waves hello',
		sendto => 0
	});

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $user1->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, '/me message was sent');
	is($msg->{msgtext}, '/me waves hello', '/me preserved in message');
};

subtest 'Message actions - delete' => sub {
	plan tests => 2;

	# Create a private message
	$DB->sqlInsert('message', {
		msgtext => 'Test message for deletion',
		author_user => $user1->{node_id},
		for_user => $user3->{node_id}
	});

	my $msg_id = $DB->sqlSelect('LAST_INSERT_ID()');

	# User3 (recipient) deletes the message
	send_message($user3, {
		message => 'anything',
		sendto => 0,
		"deletemsg_$msg_id" => 1
	});

	my $msg = $DB->sqlSelectHashref('*', 'message', "message_id=$msg_id");
	ok(!$msg, 'Message was deleted');

	# Non-recipient cannot delete message
	$DB->sqlInsert('message', {
		msgtext => 'Message for someone else',
		author_user => $user1->{node_id},
		for_user => $user3->{node_id}
	});

	$msg_id = $DB->sqlSelect('LAST_INSERT_ID()');

	send_message($user2, {
		message => 'anything',
		sendto => 0,
		"deletemsg_$msg_id" => 1
	});

	$msg = $DB->sqlSelectHashref('*', 'message', "message_id=$msg_id");
	ok($msg, 'Non-recipient cannot delete message');
};

subtest 'Message actions - archive and unarchive' => sub {
	plan tests => 4;

	# Archive test
	$DB->sqlInsert('message', {
		msgtext => 'Test message for archive',
		author_user => $user1->{node_id},
		for_user => $user3->{node_id}
	});

	my $msg_id = $DB->sqlSelect('LAST_INSERT_ID()');

	send_message($user3, {
		message => 'anything',
		sendto => 0,
		"archive_$msg_id" => 1
	});

	my $msg = $DB->sqlSelectHashref('*', 'message', "message_id=$msg_id");
	ok($msg, 'Message still exists after archive');
	is($msg->{archive}, 1, 'Message is archived');

	# Unarchive test
	send_message($user3, {
		message => 'anything',
		sendto => 0,
		"unarchive_$msg_id" => 1
	});

	$msg = $DB->sqlSelectHashref('*', 'message', "message_id=$msg_id");
	ok($msg, 'Message still exists after unarchive');
	is($msg->{archive}, 0, 'Message is unarchived');
};

done_testing();
