#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::maintenance;
use base qw(Everything::node::htmlcode);

sub node_id_equivs
{
	my ($this) = @_;
	return ["maintenance_id",@{$this->SUPER::node_id_equivs()}];
}

1;
