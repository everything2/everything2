#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::nodelet;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	# Remove cached stuff from the nodelet	
	$NODE->{nltext} = "";
	# Clean the code from line endings
	$NODE->{nlcode} = $this->_clean_code($NODE->{nlcode});
	
	return $this->SUPER::node_to_xml($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["nodelet_id", @{$this->SUPER::node_id_equivs()}];
}

1;
