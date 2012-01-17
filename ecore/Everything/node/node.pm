#!/usr/bin/perl -w

use strict;
use XML::Simple;
use Clone qw(clone);
package Everything::node::node;

sub new
{
	my ($class) = shift;
	my $this = {"xs" => XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1,"SuppressEmpty" => "", "NumericEscape" => 2)};
	return bless $this,$class;
}

sub node_to_xml
{
	my ($this, $N) = @_;
	my $NODE = Clone::clone($N);

	delete $NODE->{_ORIGINAL_VALUES};
	delete $NODE->{type};
	delete $NODE->{tableArray};
	delete $NODE->{resolvedInheritance};
	delete $NODE->{sqltablelist};

	return $this->{xs}->XMLout({node => $NODE});
}

sub xml_to_node
{
	my ($this, $xml) = @_;
	
	my $NODE = $this->{xs}->XMLin($xml);
	$NODE = $NODE->{node};
	return $this->xml_to_node_post($NODE);
}

sub xml_to_node_post
{
	my ($this, $N) = @_;
	return $N;
}

sub _clean_code
{
	my ($this, $string) = @_;

	# Remove old windows line endings
	$string =~ s|\r\n|\n|g;
	# Remove a bad control character found in the code
	$string =~ s|\cC||g;
	return $string;
}

1;
