#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::nodegroup;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	# Remove group stuff from the node	
	delete $NODE->{group};

	return $this->SUPER::node_to_xml($NODE, $dbh);
}

1;
