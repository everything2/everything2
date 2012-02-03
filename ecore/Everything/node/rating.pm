#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::rating;
use base qw(Everything::node::node);

sub node_id_equivs
{
	my ($this) = @_;
	return ["rating_id", @{$this->SUPER::node_id_equivs()}];
}

1;
