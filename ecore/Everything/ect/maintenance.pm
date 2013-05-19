#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::maintenance;
use base qw(Everything::ect::htmlcode);

sub node_id_equivs
{
	my ($this) = @_;
	return ["maintenance_id",@{$this->SUPER::node_id_equivs()}];
}

1;
