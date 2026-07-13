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

# This file mutates the shared "debuggers" usergroup (add then remove CME). If a
# previous run died mid-way it could leave CME in the group, which would fail the
# "not in group" precondition below and make the file order-dependent under
# `prove -j`. Establish a known-clean slate up front, and guarantee teardown in
# the END block, so the file is idempotent regardless of prior state.
{
    my $dbg = getNode("debuggers", "usergroup");
    $DB->removeFromNodegroup($dbg, $cme, -1) if $dbg;
}
END {
    return unless $DB && $cme;
    my $dbg = getNode("debuggers", "usergroup");
    $DB->removeFromNodegroup($dbg, $cme, -1) if $dbg;
}

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
