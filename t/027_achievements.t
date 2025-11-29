#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5 /var/everything/ecore);
use Test::More;
use Everything;
use Everything::Delegation::achievement;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

# Test that all achievement delegation functions exist and are callable
my @achievement_functions = qw(
	cooled050 cooled100
	coolnode05 coolnode10 coolnode20
	cools050 cools100 cools200 cools500
	eggs100
	experience_1 experience01000 experience10000 experience50000
	fool_s_errand
	karma20
	openwindow
	reputation_10 reputation050 reputation100 reputation200 reputationmix
	tokens100
	totalreputation01000 totalreputation05000 totalreputation10000
	usergroupbritnoders usergroupedev usergroupgods usergroupninjagirls usergroupvalhalla
	usernate
	votes01000 votes05000 votes10000 votes50000
	wheelspin1000
	writeups0100 writeups0500 writeups1000
	writeupsmonth10 writeupsmonth20 writeupsmonth30 writeupsmonthmost
	writeupsnuked100
);

# Test that each function exists and can be called
foreach my $func (@achievement_functions) {
	ok(Everything::Delegation::achievement->can($func), "Achievement function '$func' exists");
}

# Get test users
my $root = getNode("root", "user");
my $cme = getNode("Cool Man Eddie", "user");

# Test basic achievement function calls with root user
# These should return 0 or 1 without errors

# Test cooled050 - checks if user has cooled 50 writeups
my $result = Everything::Delegation::achievement::cooled050($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cooled050 returns valid result for root");

# Test cooled100 - checks if user has cooled 100 writeups
$result = Everything::Delegation::achievement::cooled100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cooled100 returns valid result for root");

# Test coolnode05 - checks if user has a writeup cooled 5+ times
$result = Everything::Delegation::achievement::coolnode05($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "coolnode05 returns valid result for root");

# Test coolnode10
$result = Everything::Delegation::achievement::coolnode10($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "coolnode10 returns valid result for root");

# Test coolnode20
$result = Everything::Delegation::achievement::coolnode20($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "coolnode20 returns valid result for root");

# Test cools050 - checks if user has received 50+ cools
$result = Everything::Delegation::achievement::cools050($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cools050 returns valid result for root");

# Test cools100
$result = Everything::Delegation::achievement::cools100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cools100 returns valid result for root");

# Test cools200
$result = Everything::Delegation::achievement::cools200($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cools200 returns valid result for root");

# Test cools500
$result = Everything::Delegation::achievement::cools500($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "cools500 returns valid result for root");

# Test eggs100 - checks if user has bought 100+ easter eggs
$result = Everything::Delegation::achievement::eggs100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "eggs100 returns valid result for root");

# Test experience_1 - checks if user has negative XP
$result = Everything::Delegation::achievement::experience_1($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "experience_1 returns valid result for root");

# Test experience01000 - checks if user has 1000+ XP
$result = Everything::Delegation::achievement::experience01000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "experience01000 returns valid result for root");

# Test experience10000
$result = Everything::Delegation::achievement::experience10000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "experience10000 returns valid result for root");

# Test experience50000
$result = Everything::Delegation::achievement::experience50000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "experience50000 returns valid result for root");

# Test fool_s_errand - always returns 1
$result = Everything::Delegation::achievement::fool_s_errand($DB, $APP, $root->{node_id});
ok($result == 1, "fool_s_errand always returns 1");

# Test karma20 - checks if user has 20+ karma
# Note: This uses global $USER so we need to test it differently
# For now, just verify it can be called
$result = Everything::Delegation::achievement::karma20($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "karma20 returns valid result");

# Test openwindow - checks if user has used "defenestrate" 15+ times
$result = Everything::Delegation::achievement::openwindow($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "openwindow returns valid result for root");

# Test reputation_10 - checks if user has a writeup with -10 or less reputation
$result = Everything::Delegation::achievement::reputation_10($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "reputation_10 returns valid result for root");

# Test reputation050 - checks if user has a writeup with 50+ reputation
$result = Everything::Delegation::achievement::reputation050($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "reputation050 returns valid result for root");

# Test reputation100
$result = Everything::Delegation::achievement::reputation100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "reputation100 returns valid result for root");

# Test reputation200
$result = Everything::Delegation::achievement::reputation200($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "reputation200 returns valid result for root");

# Test reputationmix - checks for controversial writeups
$result = Everything::Delegation::achievement::reputationmix($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "reputationmix returns valid result for root");

# Test tokens100 - checks if user has bought 100+ tokens
$result = Everything::Delegation::achievement::tokens100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "tokens100 returns valid result for root");

# Test totalreputation01000 - checks total reputation across all writeups
$result = Everything::Delegation::achievement::totalreputation01000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "totalreputation01000 returns valid result for root");

# Test totalreputation05000
$result = Everything::Delegation::achievement::totalreputation05000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "totalreputation05000 returns valid result for root");

# Test totalreputation10000
$result = Everything::Delegation::achievement::totalreputation10000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "totalreputation10000 returns valid result for root");

# Test usergroup achievements with root (who is in gods)
$result = Everything::Delegation::achievement::usergroupbritnoders($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "usergroupbritnoders returns valid result for root");

$result = Everything::Delegation::achievement::usergroupedev($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "usergroupedev returns valid result for root");

$result = Everything::Delegation::achievement::usergroupgods($DB, $APP, $root->{node_id});
ok($result == 1, "usergroupgods returns 1 for root (who is admin)");

$result = Everything::Delegation::achievement::usergroupninjagirls($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "usergroupninjagirls returns valid result for root");

$result = Everything::Delegation::achievement::usergroupvalhalla($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "usergroupvalhalla returns valid result for root");

# Test usernate - checks if user_id is 220
$result = Everything::Delegation::achievement::usernate($DB, $APP, $root->{node_id});
ok($result == 0, "usernate returns 0 for root (not user 220)");
$result = Everything::Delegation::achievement::usernate($DB, $APP, 220);
ok($result == 1, "usernate returns 1 for user_id 220");

# Test votes achievements
$result = Everything::Delegation::achievement::votes01000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "votes01000 returns valid result for root");

$result = Everything::Delegation::achievement::votes05000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "votes05000 returns valid result for root");

$result = Everything::Delegation::achievement::votes10000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "votes10000 returns valid result for root");

$result = Everything::Delegation::achievement::votes50000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "votes50000 returns valid result for root");

# Test wheelspin1000
$result = Everything::Delegation::achievement::wheelspin1000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "wheelspin1000 returns valid result for root");

# Test writeups achievements
$result = Everything::Delegation::achievement::writeups0100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeups0100 returns valid result for root");

$result = Everything::Delegation::achievement::writeups0500($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeups0500 returns valid result for root");

$result = Everything::Delegation::achievement::writeups1000($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeups1000 returns valid result for root");

# Test writeupsmonth achievements
$result = Everything::Delegation::achievement::writeupsmonth10($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeupsmonth10 returns valid result for root");

$result = Everything::Delegation::achievement::writeupsmonth20($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeupsmonth20 returns valid result for root");

$result = Everything::Delegation::achievement::writeupsmonth30($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeupsmonth30 returns valid result for root");

# Test writeupsmonthmost - no longer available, should return 0
$result = Everything::Delegation::achievement::writeupsmonthmost($DB, $APP, $root->{node_id});
ok($result == 0, "writeupsmonthmost returns 0 (achievement no longer available)");

# Test writeupsnuked100
$result = Everything::Delegation::achievement::writeupsnuked100($DB, $APP, $root->{node_id});
ok(defined($result) && ($result == 0 || $result == 1), "writeupsnuked100 returns valid result for root");

# Test with CME user to ensure functions work with different users
$result = Everything::Delegation::achievement::usergroupgods($DB, $APP, $cme->{node_id});
ok($result == 0, "usergroupgods returns 0 for CME (not admin)");

$result = Everything::Delegation::achievement::fool_s_errand($DB, $APP, $cme->{node_id});
ok($result == 1, "fool_s_errand returns 1 for any user");

done_testing();
