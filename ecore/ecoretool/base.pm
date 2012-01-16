#!/usr/bin/perl -w

use strict;
package ecoretool::base;

sub new
{
	my ($class) = @_;
	my $this;
	$this->{xs} = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
	return bless $this,$class;
}

sub get_worker_object
{
	my ($this, $type) = @_;

	my $obj;
	
	return unless $type; #TODO: error
	eval("use Everything::node::$type;");
	
	#TODO: Search in @INC first, don't be lazy
	eval("\$obj = Everything::node::$type->new();");

	if(not defined($obj))
	{
		eval("\$obj = Everything::node::node->new();");
	}

	if(not defined($obj))
	{
		print STDERR "Could not make type for $type: '$@'\n"; #TODO: error
		return;
	}

	return $obj
}

1;
