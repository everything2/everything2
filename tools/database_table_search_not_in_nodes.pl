#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

my $dbtype = getType('dbtable');

my $dbtable_nodes;
my $csr = $DB->sqlSelectMany("node_id","node","type_nodetype=$$dbtype{node_id}");
while(my $row = $csr->fetchrow_hashref())
{
	my $N = getNodeById($row->{node_id});
	$dbtable_nodes->{$N->{title}} = $N->{node_id};
}

$csr = $DB->{dbh}->prepare("SHOW TABLES");
$csr->execute();
while(my $row = $csr->fetchrow_arrayref())
{
	if(exists($dbtable_nodes->{$row->[0]}))
	{
		#print "Found node for dbtable '".$row->[0]."'\n";
		delete $dbtable_nodes->{$row->[0]};
	}else{
		print "No node found for dbtable '".$row->[0]."'\n";
	}
}

foreach my $table(keys %$dbtable_nodes)
{
	print "Not actually a table: '$table'\n";
}
