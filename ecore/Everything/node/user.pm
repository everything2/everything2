#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::user;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N) = @_;
	my $NODE = Clone::clone($N);
	
	$NODE->{passwd} = "";

	return $this->SUPER::node_to_xml($NODE);
}


sub xml_to_node_post
{
	my ($this, $N) = @_;
	$N->{passwd} = "blah";
	return $N;
}

1;
