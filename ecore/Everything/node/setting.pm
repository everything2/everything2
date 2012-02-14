#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::setting;
use base qw(Everything::node::node);

sub node_id_equivs
{
	my ($this) = @_;
	return ["setting_id",@{$this->SUPER::node_id_equivs()}];
}

sub import_no_consider
{
	my ($this) = @_;
	return ["vars", @{$this->SUPER::import_no_consider()}];
}

1;
