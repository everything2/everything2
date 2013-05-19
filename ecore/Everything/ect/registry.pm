#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::registry;
use base qw(Everything::ect::document);

sub node_id_equivs
{
	my ($this) = @_;
	return ["registry_id", @{$this->SUPER::node_id_equivs()}];
}

1;
