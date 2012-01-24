#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::htmlcode;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{code} = $this->_clean_code($NODE->{code});
	return $this->SUPER::node_to_xml($NODE, $dbh);
}

1;
