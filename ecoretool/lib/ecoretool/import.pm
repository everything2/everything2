#!/usr/bin/perl -w

use strict;
use lib qw(lib);

use ecoretool::base;
package ecoretool::import;
use base qw(ecoretool::base);

use XML::Simple;
use File::Find qw(find);
use Everything;

# Everything::Search is needed here because it is a horrible hack for object problems in Everything::NodeBase
# eval() it because for now, it doesn't exist in perlmonks
eval("use Everything::Search;"); 
use Everything::HTML; # See above
use Algorithm::Diff qw(diff);

use vars qw($files);

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

	find(sub{ if(-e $_ && $File::Find::dir ne "$$options{nodepack}/_data" && $File::Find::name =~ /\.xml$/){push @$files,$File::Find::name; }}, $options->{nodepack});
	my $rootuser = getNode("root","user");

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

		my $thistype = getType($node->{type_nodetype});
		my $dbnode = getNode($node->{node_id});

		if(not defined($dbnode))
		{
			$dbnode = getNode($node->{title},getType($node->{type_nodetype}));
		}

		if(not defined($dbnode))
		{
			print STDERR "Node needs inserting: $$node{title}\n";
			# sub insertNode ($this, $title, $TYPE, $USER, $DATA)
			delete $node->{node_id};
			my $title = $node->{title};
			delete $node->{title};
			delete $node->{type_nodetype};
			$DB->insertNode($title,$thistype,$rootuser,$node);
			print STDERR "Node inserted!\n";

		}else{
			if($node->{type_nodetype} != $dbnode->{type_nodetype})
			{
				#print STDERR "Node id collision in $$node{title}, skipping\n";
				next;
			}

			my $obj = $this->get_worker_object($thistype->{title});
			if(grep { /^$$node{node_id}$/ } @{$obj->import_skip_update()})
			{
				#print STDERR "Skipping explicit update on node_id: $$node{node_id}\n";
				next;
			}

			my $source_code_copy = $obj->node_xml_prep($dbnode, $DB->{dbh}, $options);

			foreach my $nfield (keys %$node)
			{
				next unless defined($source_code_copy->{$nfield});
				if($node->{$nfield} ne $source_code_copy->{$nfield})
				{
					if(grep { /^$nfield$/ } @{$obj->import_no_consider()})
					{
						#print STDERR "Skipping field in '$$node{title}' due to being marked no_consider: $nfield\n";
						next;	
					}
					print STDERR "Node: $$node{title}, field: $nfield needs updating\n";
					if($nfield ne "vars")
					{
						print STDERR $this->field_diff($source_code_copy->{$nfield}, $node->{$nfield});
					}else{
						print STDERR $this->field_diff($this->diffable_var_string($source_code_copy->{$nfield}), $this->diffable_var_string($node->{$nfield}));				
					}
					$dbnode->{$nfield} = $node->{$nfield};
					$DB->updateNode($dbnode,$rootuser);
					print STDERR "Node updated!\n";
				}
			}
		}
	}

}

sub diffable_var_string
{
	my ($this, $vars) = @_;
	my $varhash = {Everything::getVarHashFromStringFast($vars)};

	my $outstr ="";
	foreach my $key(sort { $b cmp $a } keys %$varhash)
	{
		$outstr .= "(var) $key = ".$varhash->{$key}."\n";
	}

	return $outstr;
}

sub field_diff
{
	my ($this, $orig, $new) = @_;
	my $output = diff([split("\n", $orig)], [split("\n", $new)]);
	if(not defined($output))
	{
		return "";
	}

	my $outstr;
	foreach my $chunk (@$output) {
		foreach my $line (@$chunk) {
			my ($sign, $lineno, $text) = @$line;
			$outstr .= sprintf("%4d$sign %s\n", $lineno+1, $text);
		}
	}

	return $outstr;
}

sub shortdesc
{
	return "Import a nodepack into the database";
}

1;
