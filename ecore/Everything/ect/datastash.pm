#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::datastash;
use base qw(Everything::ect::node);

sub node_xml_prep
{
	my ($this, $N, $dbh) = @_;
	$N->{vars} = "{}";
	return $this->SUPER::node_xml_prep($N, $dbh);
}


sub node_id_equivs
{
	my ($this) = @_;
	# Suck up a bit of a hack here to remove chained dependencies here
	# We'll just add the setting_id, and make it possible for settings to be applied to any node

	return ["setting_id",@{$this->SUPER::node_id_equivs}];
}

1;
