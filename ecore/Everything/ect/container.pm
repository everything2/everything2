#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::container;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{context} = $this->_clean_code($NODE->{context});
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["container_id", @{$this->SUPER::node_id_equivs()}];
}

1;
