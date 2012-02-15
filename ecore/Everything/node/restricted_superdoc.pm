#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::restricted_superdoc;
use base qw(Everything::node::superdoc);

sub never_export
{
	my ($this) = @_;
	return [1920211, @{$this->SUPER::never_export()}];
}

1;
