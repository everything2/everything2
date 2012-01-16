#!/usr/bin/perl -w

use strict;
use utf8;
use lib qw(lib);
use Getopt::Long;
use DBI;
use DBD::mysql;
use XML::Simple;
use ecoretool::base;
use Data::Dumper;

package ecoretool::bootstrap;
use base qw(ecoretool::base);

use Everything;

sub new
{
	my ($class) = @_;
	my $this;
	$this->{xs} = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
	return bless $this,$class;
}

sub main
{
	my ($this) = @_;	
	my $basedir = "/root/nodepack";
	
	my $dirhandle;
	my $dbtabledir = "$basedir/dbtable";
	

	opendir $dirhandle, $dbtabledir;

	my $newdbh = DBI->connect("DBI:mysql:database=everything_else;user=root");
	die "No database" unless $newdbh;
	foreach my $file(readdir($dirhandle))
	{
		next unless -e "$dbtabledir/$file" and -f "$dbtabledir/$file";
		print STDERR "Inserting $file...\n";
		my $datahandle; my $dbtable;
		open $datahandle, "$dbtabledir/$file";
		my $xmldata = $this->{xs}->XMLin($datahandle);
		close $datahandle;
		$dbtable = $xmldata->{node}->{_create_table_statement};	
		#$dbtable =~ s|--.*?\n||g;
		$dbtable =~ s|/\*.*?\*/\;||g;
		$dbtable =~ s|\n||g;
		$newdbh->do($dbtable);
	}
	closedir($dirhandle);


	my $nodetypedir = "$basedir/nodetype";
	opendir $dirhandle,"$basedir/nodetype";
	foreach my $file(readdir($dirhandle))
	{
		next unless -e "$nodetypedir/$file" and -f "$nodetypedir/$file";
		print STDERR "Inserting $file...\n";
		my $datahandle;
		open $datahandle, "$nodetypedir/$file";
		my $xmldata = $this->{xs}->XMLin($datahandle);
		close $datahandle;
		
		foreach my $table(qw|node nodetype|)
		{
			$this->_values_into_table($newdbh,$xmldata->{node},$table);
		}
		
		if(scalar(keys %{$xmldata->{node}}))
		{
			print STDERR "Leftover keys in nodetype bootstrap in $file";
		}
	}
	closedir($dirhandle);

	initEverything('everything_else');

	opendir $dirhandle,$basedir;
	foreach my $nodetype(readdir($dirhandle))
	{
		next unless -d "$basedir/$nodetype";

		next if $nodetype eq "." or $nodetype eq "..";
		next if $nodetype eq "nodetype" or $nodetype eq "_data";
		
		my $nodetypehandle;
		opendir $nodetypehandle,"$basedir/$nodetype";
		foreach my $file(readdir($nodetypehandle))
		{
			next unless -e "$basedir/$nodetype/$file" and -f "$basedir/$nodetype/$file";
			my $datahandle;
			open $datahandle,"$basedir/$nodetype/$file";
			
			print STDERR "Inserting $basedir/$nodetype/$file...\n";
			my $obj = $this->get_worker_object($nodetype);
			my $NODE = $obj->xml_to_node($datahandle);
			my $TYPE = $DB->getType($nodetype);	
			foreach my $table(split(",",$TYPE->{sqltablelist}),"node")
			{
				$this->_values_into_table($newdbh,$NODE,$table);
			}
		}
		closedir($nodetypehandle);
	}
	closedir($dirhandle);

	opendir $dirhandle,"$basedir/_data";
	foreach my $provider(readdir($dirhandle))
	{
		my $fullfile = "$basedir/_data/$provider";
		next unless -f $fullfile and -e $fullfile;
		$provider =~ s/\.xml$//g;
		no strict 'refs';

		my $obj = "Everything::dataprovider::$provider";
		$obj = $obj->new($newdbh, $basedir);
		print STDERR "Calling data in provider: $provider\n";
		$obj->data_in($fullfile);
	}
}

sub help
{

}

sub _values_into_table
{
	my ($this, $newdbh, $NODE, $table) = @_;

	my $node_columns;
	my $sth = $newdbh->prepare("EXPLAIN $table");
	$sth->execute();
	
	while (my $row = $sth->fetchrow_hashref())
	{
		push @$node_columns, $row->{Field};
	}

	$sth->finish();
			
	my $node_bootstrap_template = "INSERT INTO $table VALUES(".join(',',split(//,('?'x(@$node_columns)))).")";
	my $insertdata;

	foreach my $column (@$node_columns)
	{
		push @$insertdata, $NODE->{$column};
		delete $NODE->{$column};
	}
		
	$newdbh->do($node_bootstrap_template, undef, @$insertdata);

	return;
}

sub shortdesc
{
	return "Bootstrap a new everything database from a nodepack";
}

1;
