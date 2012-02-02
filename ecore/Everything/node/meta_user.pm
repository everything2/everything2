#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::meta_user;
use base qw(Everything::node::document);

sub node_id_equivs
{
	my ($this) = @_;

	# Like user, this is also a hack, but I'm probably going to get rid of meta-user
	return ["setting_id",@{$this->SUPER::node_id_equivs}];
}

1;
