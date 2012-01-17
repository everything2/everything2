#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::container;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $NODE) = @_;

	# Strip old windows line endings
	$NODE->{context} = $this->_clean_code($NODE->{context});
	return $this->SUPER::node_to_xml($NODE);
}

1;
