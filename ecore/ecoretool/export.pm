#!/usr/bin/perl -w

use strict;
use utf8;
use lib qw(lib);

use ecoretool::base;
package ecoretool::export;
use base qw(ecoretool::base);
use vars qw($dataproviders);

BEGIN
{
	unshift @INC, qw(lib /var/everything/ecore);
	foreach my $librarydir (@INC)
	{
		if (-d "$librarydir/Everything/dataprovider")
		{
			my $libdirhandle; opendir($libdirhandle, "$librarydir/Everything/dataprovider");
			foreach my $libfile (readdir($libdirhandle))
			{
				my $fullfile = "$librarydir/Everything/dataprovider/$libfile";
				next unless -f $fullfile and -e $fullfile;

				$libfile =~ s/\.pm//g;
				eval("use Everything::dataprovider::$libfile;");
				next if $libfile eq "base";	
				no strict 'refs';
				print STDERR $@ if $@;
				$dataproviders->{$libfile} = 1;
			}
		}		
	}
}


use Everything;
use Everything::node::node;

initEverything 'everything';

sub main
{
	my ($this) = @_;

	initEverything 'everything';
	my $node = getNode("nodetype","nodetype");

	my $csr = $DB->{dbh}->prepare("select node_id from node where type_nodetype=1");
	$csr->execute();

	$this->{basedir} = "/root/nodepack";

	my $skiptypes = {
		"e2node" => [],
		"writeup" => [], 
		"category" => [],
		"document" => [],
		"patch" => [],
		"user" => [113,952215,779713,839239], #root,klaproth,guest user,cool man eddie
		"node_forward" => [],
		"ticket" => [], 
		"draft" => [],
		"debate" => [],
		"debatecomment" => [],
		"collaboration" => [],
		"e2poll" => [],
		};

	while(my $row = $csr->fetchrow_hashref())
	{
		my $node = getNodeById($row->{node_id});
		next unless ($node); #TODO error here

		if(exists($skiptypes->{$$node{title}}))
		{
			print "Skipping type: $$node{title}\n";
			next;
		}

		my $typecsr = $DB->{dbh}->prepare("select node_id from node where type_nodetype=$$node{node_id}");
		$typecsr->execute();

		while(my $item = $typecsr->fetchrow_hashref())
		{
			my $tnode = getNodeById($item->{node_id});
			$this->xml_to_file($tnode);
			$this->{nodeidcache}->{$tnode->{node_id}} = 1;
		}
	}

	# Add in skip type exceptions
	foreach my $type(keys %$skiptypes)
	{
		foreach my $nodeid (@{$skiptypes->{$type}})
		{
			my $exception_node = getNodeById($nodeid);
			$this->xml_to_file($exception_node);
			$this->{nodeidcache}->{$exception_node->{node_id}} = 1;
		}
	}


	foreach my $provider (keys %$dataproviders)
	{
		my $obj = "Everything::dataprovider::$provider";
		no strict 'refs';
		$obj = $obj->new($DB->{dbh},$this->{basedir});
		print STDERR "Calling dataprovider: $provider\n";
		$obj->data_out($this->{nodeidcache});
	}
}

sub xml_to_file
{
	my ($this,$node) = @_;

	my $type = $$node{type}{title};
	return unless $type; #TODO: error
	my $obj = $this->get_worker_object($type);

	`mkdir -p $$this{basedir}/$type`;
	
	my $handle;

	my $outtitle = $$node{title};
	$outtitle = lc($outtitle);
	$outtitle =~ s/[\s\/\:]/_/g;
	
	if(length($$node{title}) == 0)
	{
		print "Could not write node: $$node{node_id}, invalid title\n";
		return;
	}
	my $dbh = $DB->{dbh};
	if(not defined($dbh))
	{
		print "No database handle in xml_to_file for node $$node{title}\n";
		return;
	}

	open $handle, ">/$$this{basedir}/$type/$outtitle.xml" or die "Open error '$$this{basedir}/$type/$outtitle.xml': $!";
	print $handle $obj->node_to_xml($node, $dbh);
	close $handle;
}

sub shortdesc
{
	return "Export the state of the current everything database to xml";
}

1;
