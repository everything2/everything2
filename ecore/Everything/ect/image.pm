#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::image;
use base qw(Everything::ect::node);

sub node_id_equivs
{
	my ($this) = @_;
	return ["image_id",@{$this->SUPER::node_id_equivs()}];
}

1;
