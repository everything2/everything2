#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::htmlpage;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{page} = $this->_clean_code($NODE->{page});
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["htmlpage_id",@{$this->SUPER::node_id_equivs()}];
}

1;
