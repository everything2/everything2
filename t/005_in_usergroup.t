#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

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

unless(!$APP->inDevEnvironment())
{
	ok($APP->inUsergroup(getNode("Padlock","user"),"debuggers"));
	ok($APP->inUsergroup(getNode("Padlock","user"),"debuggers","nogods"));
}

done_testing();
