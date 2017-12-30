#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
use Clone qw(clone);
package Everything::ect::nodegroup;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	# Remove group stuff from the node	
	delete $NODE->{group};

	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub xml_no_consider
{
	my ($this) = @_;
	return ["group",@{$this->SUPER::xml_no_consider()}];
}

1;
