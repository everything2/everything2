#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::notification;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	# Clean the code from line endings
	$NODE->{code} = $this->_clean_code($NODE->{code});
	$NODE->{invalid_check} = $this->_clean_code($NODE->{invalid_check});
	$NODE->{description} = $this->_clean_code($NODE->{description});
	
	return $this->SUPER::node_to_xml($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["notification_id", @{$this->SUPER::node_id_equivs()}];
}

1;
