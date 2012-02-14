#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::nodetype;
use base qw(Everything::node::node);

sub xml_no_store
{
	my ($this) = @_;
	return ["resolvedInheritance","sqltablelist","tableArray",@{$this->SUPER::xml_no_store()}];
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["nodetype_id", @{$this->SUPER::node_id_equivs()}];
}

1;
