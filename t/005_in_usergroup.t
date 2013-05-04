#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $root = getNode("root","user");
my $cme  = getNode("Cool Man Eddie", "user");

ok($APP->inUsergroup($root, "edev"));
ok($APP->inUsergroup($root, getNode("edev","usergroup")));
ok(!$APP->inUsergroup($root, "edev", "nogods"));
ok(!$APP->inUsergroup($root, getNode("edev","usergroup"), "nogods"));

ok(!$APP->inUsergroup($cme, "edev"));
ok(!$APP->inUsergroup($cme, "edev","nogods"));

ok(!$APP->inUsergroup($root, "fictitous group"));
ok(!$APP->inUsergroup($root, "fictitous group","nogods"));
	
ok(!$APP->inUsergroup($cme,"debuggers"));

ok(my $debuggers = getNode("debuggers","usergroup"));
ok($DB->insertIntoNodegroup($debuggers, -1, $cme));
ok($APP->inUsergroup($cme, "debuggers"));
ok($DB->updateNode($debuggers, -1));
ok($APP->inUsergroup($cme, "debuggers"));
ok($DB->removeFromNodegroup($debuggers, $cme, -1));
ok(!$APP->inUsergroup($cme,"debuggers"));

done_testing();
