#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::room;
use base qw(Everything::node::document);

sub node_to_xml
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{criteria} = $this->_clean_code($NODE->{criteria});
	return $this->SUPER::node_to_xml($NODE, $dbh);
}

sub node_id_equivs 
{
	my ($this) = @_;
	return ["roomdata_id", @{$this->SUPER::node_id_equivs()}];
}

sub xml_no_consider
{
	my ($this) = @_;
	return ["lastused_date",@{$this->SUPER::xml_no_consider()}];
}

1;
