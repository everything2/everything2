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

	foreach my $key(keys %$NODE)
	{
		$NODE->{$key} = $this->_sanitize($NODE->{$key});
	}
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

# Credit to: http://perl-xml.sourceforge.net/faq/
sub _sanitize
{
	my ($this,$string) = @_;

	$string =~ tr/\x91\x92\x93\x94\x96\x97/''""\-\-/;
	$string =~ s/\x85/.../sg;
	$string =~ tr/\x80-\x9F//d;
	
	return($string);
}
1;
