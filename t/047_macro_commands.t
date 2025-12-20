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

#############################################################################
# Test Macro Command functionality
#
# These tests verify:
# 1. Macro permission checks (editor-only)
# 2. Macro name validation
# 3. Macro execution with variable expansion
# 4. Error handling for missing/invalid macros
#############################################################################

# Get test users
my $editor_user = $DB->getNode('root', 'user');  # root is typically an editor
my $regular_user = $DB->getNode('guest user', 'user');

ok($editor_user, "Got editor test user (root)");
ok($regular_user, "Got regular test user (guest user)");

#############################################################################
# Test 1: Macro permission check - non-editor blocked
#############################################################################

subtest 'Macro permission check - non-editor blocked' => sub {
	plan tests => 3;

	my $vars = {};
	my $result = $APP->handleMacroCommand($regular_user, 'testmacro param1', $vars);

	ok(ref($result) eq 'HASH', "Returns a hash");
	is($result->{success}, 0, "Success is false");
	like($result->{error}, qr/aren't allowed to use macros/, "Error mentions permission");
};

#############################################################################
# Test 2: Macro name validation
#############################################################################

subtest 'Macro name validation' => sub {
	plan tests => 4;

	my $vars = {};

	# Invalid macro name with special characters
	my $result = $APP->handleMacroCommand($editor_user, 'bad!name param1', $vars);
	ok(ref($result) eq 'HASH', "Returns a hash");
	is($result->{success}, 0, "Success is false for invalid name");
	like($result->{error}, qr/isn't a valid macro name/, "Error mentions invalid name");

	# Empty args should fail
	$result = $APP->handleMacroCommand($editor_user, '', $vars);
	is($result->{success}, 0, "Success is false for empty args");
};

#############################################################################
# Test 3: Macro not found
#############################################################################

subtest 'Macro not found' => sub {
	plan tests => 3;

	my $vars = {};  # No macros defined

	my $result = $APP->handleMacroCommand($editor_user, 'nonexistent param1', $vars);

	ok(ref($result) eq 'HASH', "Returns a hash");
	is($result->{success}, 0, "Success is false");
	like($result->{error}, qr/doesn't exist/, "Error mentions macro doesn't exist");
};

#############################################################################
# Test 4: Macro execution with simple message
#############################################################################

subtest 'Macro execution - simple message' => sub {
	plan tests => 5;

	# Clear public chatter first
	$DB->sqlDelete('message', 'for_user=0');

	# Define a simple macro
	my $vars = {
		'chatmacro_testmacro' => '/say Hello world from macro'
	};

	my $result = $APP->handleMacroCommand($editor_user, 'testmacro', $vars);

	ok(ref($result) eq 'HASH', "Returns a hash");
	is($result->{success}, 1, "Success is true");
	like($result->{info}, qr/executed.*1 message/, "Info shows messages sent");

	# Verify message was inserted
	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	ok($msg, "Message was inserted");
	is($msg->{msgtext}, 'Hello world from macro', "Message text is correct");
};

#############################################################################
# Test 5: Macro variable expansion - $0 (username)
#############################################################################

subtest 'Macro variable expansion - $0 username' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	# Macro that uses $0 (username)
	my $vars = {
		'chatmacro_greet' => '/say Hello, I am $0'
	};

	my $result = $APP->handleMacroCommand($editor_user, 'greet', $vars);

	is($result->{success}, 1, "Success is true");

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	like($msg->{msgtext}, qr/Hello, I am root/, "Username expanded correctly");
};

#############################################################################
# Test 6: Macro variable expansion - $1 $2 parameters
#############################################################################

subtest 'Macro variable expansion - parameters' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	# Macro that uses parameters - just output them to public chatter
	my $vars = {
		'chatmacro_params' => '/say Testing $1 and $2'
	};

	my $result = $APP->handleMacroCommand($editor_user, 'params hello world', $vars);

	is($result->{success}, 1, "Success is true");

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	is($msg->{msgtext}, 'Testing hello and world', "Parameters expanded correctly");
};

#############################################################################
# Test 7: Macro with multiple lines
#############################################################################

subtest 'Macro with multiple lines' => sub {
	plan tests => 3;

	$DB->sqlDelete('message', 'for_user=0');

	# Multi-line macro
	my $vars = {
		'chatmacro_multi' => "/say First message\n/say Second message\n# This is a comment\n/say Third message"
	};

	my $result = $APP->handleMacroCommand($editor_user, 'multi', $vars);

	is($result->{success}, 1, "Success is true");
	like($result->{info}, qr/3 message/, "Info shows 3 messages sent");

	# Count messages
	my $count = $DB->sqlSelect('COUNT(*)', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0');

	is($count, 3, "Three messages were inserted");
};

#############################################################################
# Test 8: Macro with $N+ (all args from N onwards)
#############################################################################

subtest 'Macro variable expansion - $N+ suffix' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	# Macro that uses $1+ (all args from position 1)
	my $vars = {
		'chatmacro_echo' => '/say You said: $1+'
	};

	my $result = $APP->handleMacroCommand($editor_user, 'echo hello world test', $vars);

	is($result->{success}, 1, "Success is true");

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	is($msg->{msgtext}, 'You said: hello world test', "All args expanded correctly");
};

#############################################################################
# Test 9: Macro with curly brace to square bracket conversion
#############################################################################

subtest 'Macro curly brace conversion' => sub {
	plan tests => 2;

	$DB->sqlDelete('message', 'for_user=0');

	# Macro with curly braces (should convert to square brackets for E2 links)
	my $vars = {
		'chatmacro_link' => '/say Check out {Everything FAQ}'
	};

	my $result = $APP->handleMacroCommand($editor_user, 'link', $vars);

	is($result->{success}, 1, "Success is true");

	my $msg = $DB->sqlSelectHashref('*', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0',
		'ORDER BY message_id DESC LIMIT 1');

	is($msg->{msgtext}, 'Check out [Everything FAQ]', "Curly braces converted to square brackets");
};

#############################################################################
# Test 10: Macro with only comments/empty lines produces no output
#############################################################################

subtest 'Macro with no executable lines' => sub {
	plan tests => 3;

	$DB->sqlDelete('message', 'for_user=0');

	# Macro with only comments
	my $vars = {
		'chatmacro_empty' => "# This is a comment\n# Another comment\n\n"
	};

	my $result = $APP->handleMacroCommand($editor_user, 'empty', $vars);

	is($result->{success}, 0, "Success is false");
	like($result->{error}, qr/produced no output/, "Error mentions no output");

	# Verify no messages
	my $count = $DB->sqlSelect('COUNT(*)', 'message',
		'author_user=' . $editor_user->{node_id} . ' AND for_user=0');

	is($count, 0, "No messages were inserted");
};

#############################################################################
# Cleanup
#############################################################################

$DB->sqlDelete('message', 'for_user=0');

done_testing();
