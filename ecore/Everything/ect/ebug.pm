#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::ebug;
use base qw(Everything::ect::document);

sub node_id_equivs
{
	my ($this) = @_;
	return ["ebug_id", @{$this->SUPER::node_id_equivs()}];
}

1;
