#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::e2node;
use base qw(Everything::ect::nodegroup);

sub node_id_equivs
{
	my ($this) = @_;
	return ["e2node_id", @{$this->SUPER::node_id_equivs()}];
}

1;
