#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::tutorialstep;
use base qw(Everything::node::document);

sub node_id_equivs
{
	my ($this) = @_;
	return ["tutorialstep_id", @{$this->SUPER::node_id_equivs()}];
}

1;
