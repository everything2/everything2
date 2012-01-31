#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::nodetype;
use base qw(Everything::node::node);

sub xml_no_consider
{
	my ($this) = @_;
	return ["resolvedInheritance","sqltablelist","tableArray",@{$this->SUPER::xml_no_consider()}];
}

1;
