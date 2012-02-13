#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::nodelet;
use base qw(Everything::node::node);

sub node_xml_prep
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	# Remove cached stuff from the nodelet	
	$NODE->{nltext} = "";
	# Clean the code from line endings
	$NODE->{nlcode} = $this->_clean_code($NODE->{nlcode});
	
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["nodelet_id", @{$this->SUPER::node_id_equivs()}];
}

sub xml_no_consider
{
	my ($this) = @_;
	return ["lastupdate", @{$this->SUPER::xml_no_consider()}];
}
1;
