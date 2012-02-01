#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::e2client;
use base qw(Everything::node::document);

sub node_id_equivs
{
	my ($this) = @_;
	return ["e2client_id", @{$this->SUPER::node_id_equivs()}];
}

1;
