#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More tests => 13;
use diagnostics;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $user = getNode("Cool Man Eddie","user");
ok(exists($user->{node_id}), "Got the user okay");
ok($APP->userCanCloak($user) == 0, "Can't cloak by default");

ok($APP->setParameter($user, -1, "cancloak", "1"), "Set cancloak in node params");
ok($APP->userCanCloak($user) == 1, "Can cloak now due to node params");
ok($APP->delParameter($user, -1, "cancloak", "1"), "Remove the node parameter");
ok($APP->userCanCloak($user) == 0, "Can't cloak after parameter removed");

ok($APP->setParameter($user, -1, "level_override", "30") == 1, "Set the user's level to be high enough to cloak");
ok($APP->userCanCloak($user) == 1, "User can cloak due to high level-ness");
ok($APP->getParameter($user, "level_override") == 30, "Just testing getParameter while we are here");
ok($APP->getLevel($user) == 30, "Test the level override function while we are here");
ok($APP->delParameter($user, -1, "level_override") == 1, "Delete the level override");
ok($APP->userCanCloak($user) == 0, "User can no longer cloak");

ok($APP->userCanCloak(getNode("root","user")) == 1, "An admin can cloak");

