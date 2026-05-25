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

# Regression coverage for #4058: easter-egg commands previously dropped
# the raw "/cmd target" into chat verbatim. The handler now substitutes
# the action text from the 'egg commands' setting node and emits it as
# a /me-style action so the React chatterbox renders it correctly.
#
# Concurrency notes (flakiness hardening, May 2026):
# * Egg choice was originally `(keys %$egg_vars)[0]`. Perl hash key order
#   varies between runs, so different runs picked different eggs — some
#   contained regex metacharacters or non-ASCII that broke the like()
#   assertions. We now sort and filter to "safe" eggs deterministically.
# * Reading back the row by `ORDER BY message_id DESC LIMIT 1` raced
#   against any other parallel test sending public chatter as root in
#   the same window. We now look up rows by msgtext substring so we
#   always find OUR row regardless of what else is happening.
# * `sqlDelete('message', 'for_user=0')` wiped chatter belonging to
#   other concurrently-running test files. Dropped — no longer needed.
subtest 'Easter egg commands - action text substitution' => sub {
	my $egg_setting = $DB->getNode('egg commands', 'setting');
	plan skip_all => "No 'egg commands' setting in this env" unless $egg_setting;

	my $egg_vars = $APP->getVars($egg_setting);
	plan skip_all => "egg commands setting has no vars" unless $egg_vars && %$egg_vars;

	# Restrict to eggs whose action text is plain ASCII / safe punctuation
	# so substring matching and regex quoting behave predictably. Sort the
	# survivors so the choice is the same on every run.
	my @safe = sort grep {
		( $egg_vars->{$_} // '' ) =~ m{\A[\w\s.,!?'"~/-]+\z}
	} keys %$egg_vars;
	my $with_tilde = ( grep { $egg_vars->{$_} =~ /~/ } @safe )[0];
	my $no_tilde   = ( grep { $egg_vars->{$_} !~ /~/ } @safe )[0];
	plan skip_all => "Couldn't find both ~ and non-~ safe eggs"
		unless $with_tilde && $no_tilde;
	plan tests => 6;

	# Give the sender enough eggs to spend (root)
	my $sender_vars = Everything::getVars($user1);
	$sender_vars->{easter_eggs} = 5;
	Everything::setVars( $user1, $sender_vars );

	# Use $user3 (Cool Man Eddie) as the target — it exists and isn't the sender
	my $target = $user3->{title};

	# Look up OUR row by msgtext substring rather than "the latest from
	# this author" so other parallel tests don't trick us into asserting
	# against their chatter.
	my $find_by_substr = sub {
		my ($author_id, $needle) = @_;
		my $like = $DB->{dbh}->quote('%' . $needle . '%');
		return $DB->sqlSelectHashref(
			'*', 'message',
			"author_user=$author_id AND for_user=0 AND msgtext LIKE $like",
			'ORDER BY message_id DESC LIMIT 1'
		);
	};

	# 1) Egg with ~ placeholder: substitute target in place
	my $expected_w = $egg_vars->{$with_tilde};
	$expected_w =~ s/~/$target/g;
	send_message( $user1, { message => "/$with_tilde $target", sendto => 0 } );
	my $msg = $find_by_substr->( $user1->{node_id}, $expected_w );
	ok( $msg, "egg /$with_tilde produced a chatter row" );
	like( ( $msg ? $msg->{msgtext} : '' ), qr{^/me\b},
		'emitted as /me action (not raw /cmd)' );
	like( ( $msg ? $msg->{msgtext} : '' ), qr/\Q$expected_w\E/,
		"~ placeholder substituted with target ($with_tilde -> $target)" );

	# 2) Egg without ~ placeholder: target appended
	my $expected_n = $egg_vars->{$no_tilde} . ' ' . $target;
	send_message( $user1, { message => "/$no_tilde $target", sendto => 0 } );
	$msg = $find_by_substr->( $user1->{node_id}, $expected_n );
	ok( $msg, "egg /$no_tilde produced a chatter row" );
	like( ( $msg ? $msg->{msgtext} : '' ), qr{^/me\b},
		'emitted as /me action' );
	like( ( $msg ? $msg->{msgtext} : '' ), qr/\Q$expected_n\E/,
		"non-~ egg appends target ($no_tilde $target)" );
};

# Regression coverage for #4058 follow-up: failure modes used to all
# return the generic "Message not posted" with no row inserted. Each
# real failure now returns a specific error, and an unknown command
# (not actually an egg) falls through to plain chatter.
#
# Same concurrency hardening as the substitution subtest: pick the
# probe egg deterministically; find OUR fallthrough chatter row by a
# unique probe string rather than "latest from author"; don't bulk
# delete shared chatter.
subtest 'Easter egg commands - failure modes give specific feedback' => sub {
	plan tests => 4;

	my $egg_setting = $DB->getNode('egg commands', 'setting');
	plan skip_all => "No 'egg commands' setting in this env" unless $egg_setting;

	my $egg_vars = $APP->getVars($egg_setting);
	my $known_egg = ( sort grep { length( $egg_vars->{$_} // '' ) } keys %$egg_vars )[0];
	plan skip_all => "no usable egg in this env" unless $known_egg;

	# Give the sender eggs so failures aren't masked by "out of eggs"
	my $sender_vars = Everything::getVars($user1);
	$sender_vars->{easter_eggs} = 5;
	Everything::setVars( $user1, $sender_vars );

	# 1) Unknown command → falls through to plain chatter (no error).
	#    Use a uniquely-tagged command name so we can find OUR row
	#    without colliding with parallel tests.
	my $probe = 'definitelynotanegg_' . $$ . '_' . time();
	send_message( $user1,
		{ message => "/$probe someuser", sendto => 0 } );
	my $like = $DB->{dbh}->quote("%/$probe%");
	my $msg = $DB->sqlSelectHashref( '*', 'message',
		'author_user=' . $user1->{node_id}
			. " AND for_user=0 AND msgtext LIKE $like",
		'ORDER BY message_id DESC LIMIT 1' );
	like( $msg && $msg->{msgtext}, qr{^/\Q$probe\E\b},
		'unknown slash-command falls through to plain chatter' );

	# 2) Known egg + nonexistent target → specific error, no chatter row
	my $result = $APP->processMessageCommand( $user1,
		"/$known_egg user_that_does_not_exist_12345", $sender_vars );
	is( $result->{success}, 0, 'unknown target returns success=0' );
	like( $result->{error}, qr/not found/i,
		'error mentions the user was not found' );

	# 3) Known egg + self target → specific error
	$result = $APP->processMessageCommand( $user1,
		"/$known_egg $user1->{title}", $sender_vars );
	like( $result->{error}, qr/yourself/i,
		'self-target error mentions yourself' );
};

done_testing();
