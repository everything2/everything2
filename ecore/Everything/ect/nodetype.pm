#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::ect::nodetype;
use base qw(Everything::ect::node);

sub xml_no_store
{
	my ($this) = @_;
	return ["resolvedInheritance","sqltablelist","tableArray",@{$this->SUPER::xml_no_store()}];
}

sub node_xml_prep
{
	my ($this, $NODE, $dbh) = @_;

	if($NODE->{sqltable} eq "")
	{
		delete $NODE->{datatype};
	}
	return $this->SUPER::node_xml_prep($NODE, $dbh);
}

sub node_id_equivs
{
	my ($this) = @_;
	return ["nodetype_id", @{$this->SUPER::node_id_equivs()}];
}

1;
