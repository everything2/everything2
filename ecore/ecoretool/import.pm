#!/usr/bin/perl -w

use strict;
use lib qw(lib);

use ecoretool::base;
package ecoretool::import;
use base qw(ecoretool::base);

use XML::Simple;
use File::Find qw(find);
use Everything;

use vars qw($files);

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

	"nodepack" =>
	{
		"alias" => ["n"],
		"type" => "s",
		"default" => "./nodepack",
		"help" => "The directory to load the nodepack from",
	},
	};
}

sub main
{
	my ($this) = @_;

	my $options = $this->_handle_inputs();

	initEverything $options->{database};

	find(sub{ if(-e $_&& $File::Find::name =~ /\.xml$/){push @$files,$File::Find::name; }}, $options->{nodepack});

	foreach my $nodexml(@$files)
	{
		my $node = $this->{xs}->XMLin($nodexml);
		#print STDERR "Inspecting node: $nodexml\n";

		unless(exists($node->{node}))
		{
			print STDERR "Malformed node XML (no node construct): $nodexml\n";
			next;
		}

		$node = $node->{node};

		unless(exists($node->{node_id}))
		{
			print STDERR "Malformed node XML (no node_id): $nodexml\n";
			next;
		}

		my $dbnode = getNode($node->{node_id});

		if(not defined($dbnode))
		{
			print STDERR "Node needs inserting: $$node{title}\n";
		}else{
			foreach my $nfield (keys %$node)
			{
				if($node->{$nfield} ne $dbnode->{$nfield})
				{
					print STDERR "Node: $$node{title}, field: $nfield needs updating\n";
				}		
			}
		}
	}

}

sub shortdesc
{
	return "Import a nodepack into the database";
}

1;
