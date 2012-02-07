#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::user;
use base qw(Everything::node::document);

sub node_to_xml
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);
	
	$NODE->{passwd} = "";

	return $this->SUPER::node_to_xml($NODE, $dbh);
}


sub xml_to_node_post
{
	my ($this, $N) = @_;
	$N->{passwd} = "blah";
	return $this->SUPER::xml_to_node_post($N);
}

sub node_id_equivs
{
	my ($this) = @_;
	# Suck up a bit of a hack here to remove chained dependencies here
	# We'll just add the setting_id, and make it possible for settings to be applied to any node

	return ["user_id","setting_id",@{$this->SUPER::node_id_equivs}];
}

sub xml_no_consider
{
	my ($this) = @_;
	return ["in_room", "experience","session_id","validationkey",@{$this->SUPER::xml_no_consider()}];
}

1;
