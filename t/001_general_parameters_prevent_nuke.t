#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More qw(no_plan);
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

my $htmlcode = getNode("googleads", "htmlcode");
ok(defined($htmlcode->{node_id}), "Able to get 'googleads','htmlcode'");
ok(my $available_parameters = $APP->getParametersForType("htmlcode"), "Get available parameters for htmlcode");
ok(exists($available_parameters->{prevent_nuke}), "Prevent nuke exists on htmlcode");
ok($APP->setParameter($htmlcode, -1, "prevent_nuke", 1), "Can assign prevent_nuke to an htmlcode");
ok($APP->getParameter($htmlcode, "prevent_nuke") == 1, "Can get prevent_nuke from an htmlcode");
ok($APP->delParameter($htmlcode, -1, "prevent_nuke") == 1, "Can delete prevent_nuke from an htmlcode");

my $user = getNode("root", "user");
ok(defined($user->{node_id}), "Able to get 'root','user'");

ok($available_parameters = $APP->getParametersForType("user"), "Get available parameters for user");
ok(exists($available_parameters->{cancloak}), "cancloak exists on user");
ok(exists($available_parameters->{prevent_nuke}), "prevent_nuke exists on user");
ok($APP->setParameter($user, -1, "prevent_nuke", 1), "Can set prevent_nuke on a user");
ok($APP->getParameter($user, "prevent_nuke") == 1, "Can get prevent_nuke on a user");
ok($APP->delParameter($user, -1, "prevent_nuke") == 1, "Can delete prevent_nuke from user");

