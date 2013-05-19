#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::ect::nodetest;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);
	# Clean the code from line endings
	$NODE->{nlcode} = $this->_clean_code($NODE->{nodetest_code});
	
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["nodetest_id", @{$this->SUPER::node_id_equivs()}];
}

1;
