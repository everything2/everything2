#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

my $csr = $DB->sqlSelectMany('user_id','user');
my $type = getType('user');

my $nodeletstats = {};

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

	next unless $v->{nodelets};
        my $currentnodelets = [split(",", $v->{nodelets})];
        my $newnodelets = [];
	my $has_new_writeups = 0;
	foreach my $nodelet (@$currentnodelets)
	{
		next if $nodelet eq '';
		if($nodelet == 263)
		{
			$has_new_writeups = 1; #Has the true new writeups
		}
	}

	foreach my $nodelet (@$currentnodelets)
	{
		next if $nodelet eq '';
		if($nodelet != 1868940)
		{
			push @$newnodelets, $nodelet
		}elsif(!$has_new_writeups)
		{
			push @$newnodelets, 263;
		}

		$nodeletstats->{$nodelet}++;
	}

#	my $newnodeletstring = join(",",@$newnodelets);
#	if($newnodeletstring ne $v->{nodelets})
#	{
#		print qq|$N->{title} ($N->{node_id}) nodelets have changed: old: "$v->{nodelets}" new: "$newnodeletstring"\n|;
#		$v->{nodelets} = $newnodeletstring;
#       	setVars($N,$v);
#	      	$DB->updateNode($N,-1);
#	}
}


foreach my $key (sort {$nodeletstats->{$b} <=> $nodeletstats->{$a}} keys %$nodeletstats)
{
	my $n = getNodeById($key);
	print "$$n{title} ($key): ".$nodeletstats->{$key}."\n";
}

