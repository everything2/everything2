#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::rawdata;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{datacode} = $this->_clean_code($NODE->{datacode});

	if($NODE->{datatype} eq "")
	{
		delete $NODE->{datatype};
	}
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["rawdata_id", @{$this->SUPER::node_id_equivs()}];
}

1;
