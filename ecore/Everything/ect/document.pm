#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
package Everything::ect::document;

use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $NODE, $dbh) = @_;

	# Strip old windows line endings
	$NODE->{doctext} = $this->_clean_code($NODE->{doctext});
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub xml_no_store
{
	my ($this) = @_;
	return ["edittime",@{$this->SUPER::xml_no_store()}];
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["document_id", @{$this->SUPER::node_id_equivs()}];
}

1;
