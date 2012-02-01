#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::e2node;
use base qw(Everything::node::nodegroup);

sub node_id_equivs
{
	my ($this) = @_;
	return ["e2node_id", @{$this->SUPER::node_id_equivs()}];
}

1;
