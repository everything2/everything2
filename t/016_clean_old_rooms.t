#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Test::More tests => 4;
use diagnostics;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $long_enough = '2000-01-01 12:00:00';
my $testname = 'test old room';

# Clean up any existing tomb entries from previous test runs
$DB->sqlDelete('tomb', "title=" . $DB->quote($testname));

$DB->nukeNode($DB->getNode($testname,'room'), -1);

my $val = $DB->getNode("Valhalla","room");
my $root = $DB->getNode("root","user");
$DB->insertNode($testname,$DB->getType("room"), $root, {"lastused_date" => $long_enough, "criteria" => '1;',"doctext" => "hello!"}, 'skip maintenance');

my $tor = $DB->getNode($testname, "room");
$val->{"lastused_date"} = $long_enough;
$DB->updateNode($val, -1);

$APP->clean_old_rooms;

$tor = $DB->getNode($testname, "room", 'force');
$val = $DB->getNode("Valhalla","room", 'force');
ok(!defined($tor),"Test old room is deleted");
ok(defined($val),"Valhalla is fine");

my $now = $DB->sqlSelect("NOW()");

$DB->insertNode($testname,$DB->getType("room"), $root, {"lastused_date" => $now, "criteria" => '1;',"doctext" => "hello!"}, 'skip maintenance');
$APP->clean_old_rooms;

$tor = $DB->getNode($testname, "room");
ok(defined($tor), "Newer rooms are fine");
$DB->nukeNode($tor, -1);

$DB->insertNode($testname,$DB->getType("room"), $root, {"criteria" => '1;',"doctext" => "hello!"}, 'skip maintenance');
$APP->clean_old_rooms;

$tor = $DB->getNode($testname, "room");
# #4087: roomdata.lastused_date now defaults to curdate() instead of the legacy
# '0000-00-00'. A freshly-created, never-entered room therefore gets the normal
# room_cleanup_threshold grace period rather than being instantly reaped (the old
# zero-date default made UNIX_TIMESTAMP()=0, so such rooms vanished on the very
# next clean_old_rooms run, even seconds after creation). It is still reaped once
# it has gone unused past the threshold, like any other stale room.
ok(defined($tor), "Never-used rooms get a grace period, not instant deletion (#4087)");
$DB->nukeNode($tor, -1) if $tor;
