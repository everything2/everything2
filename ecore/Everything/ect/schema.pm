#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::schema;
use base qw(Everything::ect::document);

sub node_id_equivs
{
	my ($this) = @_;
	return ["e2schema_id", @{$this->SUPER::node_id_equivs}];
}

1;
