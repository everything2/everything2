#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

if(!$APP->inDevEnvironment())
{
	ok(my $broken_nodes = getNode("Broken nodes","e2node"));
	ok($APP->isMaintenanceNode($broken_nodes));
	ok(my $broken_nodes_wu = getNodeById(379712)); #Virgil's wu in Broken nodes
	ok($APP->isMaintenanceNode($broken_nodes_wu));
	ok(my $rootlog = getNode("root log: November 2012","e2node"));
	ok(!$APP->isMaintenanceNode($rootlog));
	ok(!$APP->isMaintenanceNode($rootlog->{group}[0]));
}


done_testing();
