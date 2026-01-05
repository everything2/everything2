#!/usr/bin/perl -w

use strict;
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
use Everything::ect::node;

sub main
{
	my ($this) = @_;

	$this->{options} = $this->_handle_inputs();

	initEverything $this->{options}->{database};

	my $node = getNode("nodetype","nodetype");

	my $csr = $DB->{dbh}->prepare("select node_id from node where type_nodetype=1");
	$csr->execute();

	$this->{basedir} = $this->{options}->{nodepack};

	my $skiptypes = $this->_skippable_types();

	while(my $row = $csr->fetchrow_hashref())
	{
		my $node = getNodeById($row->{node_id});
		next unless ($node); #TODO error here

		if(exists($skiptypes->{$$node{title}}))
		{
			print "Skipping type: $$node{title}\n";
			next;
		}

		my $typecsr = $DB->{dbh}->prepare("select node_id,title from node where type_nodetype=$$node{node_id}");
		$typecsr->execute();

		while(my $item = $typecsr->fetchrow_hashref())
		{
			my $typeobj = $this->get_worker_object($$node{title});
			if(grep {/^$$item{node_id}$/} @{$typeobj->never_export()})
			{
				print "Explicitly skipping export on $$node{title}: '$$item{title}'\n";
				next;
			}
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

	unless($this->{options}->{'skip-data'})
	{
		foreach my $provider (keys %$dataproviders)
		{
			my $obj = "Everything::dataprovider::$provider";
			no strict 'refs';
			$obj = $obj->new($DB->{dbh},$this->{basedir});
			print STDERR "Calling dataprovider: $provider\n";
			$obj->data_out($this->{nodeidcache});
		}
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
	$outtitle =~ s/[\s\/\:\?\'\"\%]/_/g;
	
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

	open $handle, ">:encoding(UTF-8)", "$$this{basedir}/$type/$outtitle.xml" or die "Open error '$$this{basedir}/$type/$outtitle.xml': $!";
	print $handle $obj->node_to_xml($node, $dbh, $this->{options});
	close $handle;
}

sub shortdesc
{
	return "Export the state of the current everything database to xml";
}

sub _inputs
{
	return 
	{
	"user" => 
	{
		"alias" => ["u"],
		"type" => "s",
		"default" => "root",
		"help" => "The user to connect to the database with. Note, currently unsupported; value is in everything.conf",
	},
	"password" =>
	{
		"alias" => ["p"],
		"type" => "s",
		"default" => "",
		"help" => "The password to the database for the user. Node, currently unsupported; value is in everything.conf",
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
		"help" => "The directory to export the nodepack to",
	},
	"skip-data" =>
	{
		"default" => 0,
		"help" => "Skip exporting of the data providers",
	},
	};
}

1;
