#!/usr/bin/perl -w

use strict;
use warnings;
use XML::Simple;

package Everything::dataprovider::base;

sub new
{
	my ($class, $dbh, $basedir) = @_;

	my $this = {"dbh" => $dbh, "basedir" => $basedir, "xs" => XML::Simple->new("KeepRoot" => 1, "NoAttr" => 1,"SuppressEmpty" => 1, "NumericEscape" => 2, "KeyAttr" => {}, "ForceArray" => ['vars'])};
	return bless $this,$class;
}

sub xml_out
{
	my ($this, $data) = @_;

	my $filename = ref $this;
	$filename =~ s/.*://g;

	# Use basedir if provided, otherwise use /tmp for test environments
	my $basedir = $this->{basedir} || '/tmp';
	`mkdir -p $basedir/_data/`;

	my $handle;
	open $handle, ">","$basedir/_data/$filename.xml";
	print $handle $this->{xs}->XMLout({"$filename" => $data});
	close $handle;
	return;
}

sub data_out
{
	my ($this) = @_;
	return;
}

sub _hash_insert
{
	my ($this, $table, $hash) = @_;

	my $sth = $this->{dbh}->prepare("EXPLAIN $table");
	$sth->execute();

	my $node_columns;

	while (my $row = $sth->fetchrow_hashref())
	{
		push @$node_columns, $row->{Field};
	}

	my $template = "INSERT INTO $table VALUES(".join(",",split(//,'?'x(@$node_columns))).")";

	my $values;
	foreach my $column (@$node_columns)
	{
		push @$values, $hash->{$column};
	}

	$this->{dbh}->do($template, undef, @$values);
	return;
}

1;
