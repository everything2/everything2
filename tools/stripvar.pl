#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

my $csr = $DB->sqlSelectMany('user_id','user');
my $type = getType('user');
my $varstats;
my $specialstats;

my $tostrip = "includedJS";

while(my $row = $csr->fetchrow_hashref())
{
	my $N = getNodeById($row->{user_id});
	unless($N)
	{
		print "Bad data in user table: '".$row->{user_id}."'\n";
		next;
	}

	if($N->{type_nodetype} != $type->{node_id})
	{
		print "Strange data mismatch with stuff from user: '$$N{node_id}'\n";
		next;
	}
	my $v = getVars($N);
	print "Inspecting: $$N{title}\n";
	next unless exists $v->{$tostrip};
	print "$$N{title} has '$tostrip'\n";
	delete $v->{$tostrip};
	setVars($N,$v);
	$DB->updateNode($N,-1);
	#exit;
}
