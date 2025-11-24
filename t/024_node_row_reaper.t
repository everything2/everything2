#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Test::More tests => 5;
use diagnostics;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment)
{
	plan skip_all => "Not in the development environment";
	exit;
}


my $node_row = $DB->getNode("node row", "oppressor_superdoc");

my $e2node = "nodeshell_for_testing";
my $cme = $DB->getNode("Cool Man Eddie","user");
my $root = $DB->getNode("root","user");

# Clean up tomb entries from previous test runs
my $writeup_title = "$e2node (idea)";
$DB->sqlDelete('tomb', "title=" . $DB->quote($e2node));
$DB->sqlDelete('tomb', "title=" . $DB->quote($writeup_title));

$DB->nukeNode($DB->getNode($e2node, "e2node"), -1);
$DB->insertNode($e2node,$DB->getType("e2node"), $root);
my $e2node_parent = $DB->getNode($e2node, "e2node");
$e2node_parent->{createdby_user} = $cme->{node_id};
$DB->updateNode($e2node_parent, -1);

$DB->nukeNode($DB->getNode($writeup_title, "writeup"),-1);

$DB->insertNode($writeup_title, $DB->getType("writeup"), $cme, {"doctext" => "This is a test writeup!"});
my $writeup = $DB->getNode($writeup_title, "writeup");
my $results = $APP->process_reaper_targets;

ok(!defined($results->[0]),"Empty reaper list to start");

$DB->sqlInsert("weblog",{"weblog_id"=> $node_row->{node_id}, "to_node" => $writeup->{node_id}, "linkedby_user" => $root->{node_id}});

$results = $APP->process_reaper_targets;
ok($results->[0]->{killer} == $root->{node_id}, "Marked target is killed");
ok($results->[0]->{node} == $writeup->{node_id}, "Marked target is identified");

$results = $APP->process_reaper_targets;
ok(!defined($results->[0]), "Targets don't persist post-reap");
ok(!defined($DB->getNode($writeup_title, "writeup")),"Marked target is gone");
