#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use XML::Simple;
use Clone qw(clone);
package Everything::node::nodelet;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N) = @_;
	my $NODE = Clone::clone($N);

	# Remove cached stuff from the nodelet	
	$NODE->{nltext} = "";

	return $this->SUPER::node_to_xml($NODE);
}

1;
