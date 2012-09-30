#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

my $csr = $DB->sqlSelectMany('user_id','user');
my $type = getType('user');
my $varstats;

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
	print "Inspecting: $$N{node_id}\n";
	my $v = getVars($N);

	foreach my $key(keys %$v)
	{
		$varstats->{$key} ||= 0;
		$varstats->{$key}++;
	}
}

foreach my $key (sort {$varstats->{$b} <=> $varstats->{$a}} keys %$varstats)
{
	print "$key: ".$varstats->{$key}."\n";
}
