#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::fullpage;
use base qw(Everything::node::document);

sub import_skip_update
{
	my ($this) = @_;
	return [1101708, @{$this->SUPER::import_skip_update}];
}

1;
