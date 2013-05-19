#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::mvtest;
use base qw(Everything::ect::setting);

sub node_id_equivs
{
	my ($this) = @_;
	return ["mvtest_id",@{$this->SUPER::node_id_equivs()}];
}

1;
