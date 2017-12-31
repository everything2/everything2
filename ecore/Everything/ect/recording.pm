#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::recording;
use base qw(Everything::ect::node);

sub node_id_equivs
{
	my ($this) = @_;
	return ["recording_id", @{$this->SUPER::node_id_equivs()}];
}

1;
