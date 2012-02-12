#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use ecoretool::base;
package ecoretool::nodeidmove;
use base qw(ecoretool::base);

use Everything;
use DBI;
use DBD::mysql;
use XML::Simple;

sub new
{
	my ($class) = @_;
	my $this;
	$this->{xs} = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
	return bless $this,$class;
}

sub _inputs
{
	return {
	"from" => 
	{
		"alias" => ["fromnode"],
		"type" => "s",
		"default" => "",
		"help" => "The node id of the node to move",
	},
	"to" =>
	{
		"alias" => ["tonode"],
		"type" => "s",
		"default" => "",
		"help" => "The node id to move the from node to",
	},
	"user" => 
	{
		"alias" => ["u"],
		"type" => "s",
		"default" => "root",
		"help" => "The user to connect to the database with",
	},
	"password" =>
	{
		"alias" => ["p"],
		"type" => "s",
		"default" => "",
		"help" => "The password to the database for the user",
	},
	"database" => 
	{
		"alias" => ["d"],
		"type" => "s",
		"default" => "everything",
		"help" => "The database to connect to",
	},
	};
}

sub main
{
	my ($this) = @_;
	my $options = $this->_handle_inputs();
	if($options->{from} eq "" or $options->{to} eq "")
	{
		print STDERR "Need both --to and --from\n";
		exit;
	}

	if($options->{from} !~ /^\d+$/ or $options->{to} !~ /^\d+$/)
	{	
		print STDERR "The node_ids for --to and --from need to both be numbers\n";
		exit;
	}

	initEverything($$options{database});

	my $Nfrom = getNodeById($options->{from});
	my $Nto = getNodeById($options->{to});

	if(not defined($Nfrom))
	{
		print STDERR "The node in --from does not exist\n";
		exit;
	
	}

	if(defined($Nto))
	{
		print STDERR "Node id collision on --to detected. Aborting\n";
		exit;
	}

	print STDERR "Moving node_id:$$options{from} to node_id:$$options{to}\n";

	my $TYPE = getType($Nfrom->{type_nodetype});
		
	foreach my $table(split(",",$TYPE->{sqltablelist}),"node")
	{
		print STDERR "..updating table: $table\n";

		if(exists($Nfrom->{$table."_id"}))
		{
			$DB->{dbh}->do("UPDATE $table SET $table"."_id=$$options{to} WHERE $table"."_id=$$options{from}");
		}
	}

	print STDERR "done\n";
}

sub shortdesc
{
	return "Move a node in the database";
}

1;
