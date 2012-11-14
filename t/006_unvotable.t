#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';

if(!$APP->inDevEnvironment())
{
	ok(my $broken_nodes = getNode("Broken nodes","e2node"));
	ok($APP->isUnvotable($broken_nodes));
	ok(my $broken_nodes_wu = getNodeById(379712)); #Virgil's wu in Broken nodes
	ok($APP->isUnvotable($broken_nodes_wu));
	ok(my $rootlog = getNode("root log: November 2012","e2node"));
	ok(!$APP->isUnvotable($rootlog));
	ok(!$APP->isUnvotable($rootlog->{group}[0]));

	my $testwriteup = getNodeById(1970029);
	ok($APP->isUnvotable($testwriteup));

	# Sister writeup to testwriteup
	ok(!$APP->isUnvotable(689897));
}


done_testing();
