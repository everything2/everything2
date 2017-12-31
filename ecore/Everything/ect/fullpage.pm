#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::fullpage;
use base qw(Everything::ect::document);

sub import_skip_update
{
	my ($this) = @_;
	return [1101708, @{$this->SUPER::import_skip_update}];
}

1;
