#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

my $csr = $DB->sqlSelectMany('user_id','user');
my $type = getType('user');
my $varstats;
my $specialstats;

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
	#print "Inspecting: $$N{node_id}\n";
	my $v = getVars($N);


	foreach my $key(keys %$v)
	{
		if($key =~ /\%/ or $key =~ /^\d+$/ or $key =~ /\n/ or $key =~ /\s/ or $key eq '' or length($key) <= 2)
		{
			print "Strage keydata in user: '$$N{node_id}'\n";
		}

		$varstats->{$key} ||= 0;
		$varstats->{$key}++;

		if($key eq 'informmsgignore')
		{
			$specialstats->{$v->{$key}} ||= 0;
			$specialstats->{$v->{$key}}++;
		}
	}
}

foreach my $key (sort {$varstats->{$b} <=> $varstats->{$a}} keys %$varstats)
{
	print "$key: ".$varstats->{$key}."\n";
}

#print "Special stats:\n";
#
#foreach my $key (keys %$specialstats)
#{
#	print "$key: ".$specialstats->{$key}."\n";
#}
