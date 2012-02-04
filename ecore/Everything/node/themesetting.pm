#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::themesetting;
use base qw(Everything::node::setting);

sub node_id_equivs
{
	my ($this) = @_;
	return ["themesetting_id",@{$this->SUPER::node_id_equivs()}];
}

1;
