#!/usr/bin/perl -w

use strict;
use lib qw(lib);
package Everything::node::user;
use base qw(Everything::node::document);

sub node_xml_prep
{
	my ($this, $N, $dbh) = @_;
	$N->{passwd} = "";
	return $this->SUPER::node_xml_prep($N, $dbh);
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

sub xml_vars_no_store
{
	my ($this) = @_;
	return ["browser", "ipaddy","level","nwriteupsupdate",@{$this->SUPER::xml_vars_no_store()}];
}

sub xml_no_store
{
	my ($this) = @_;
	return ["lasttime","numwriteups","merit","user_salt","in_room","karma","GP","experience","session_id","validationkey",@{$this->SUPER::xml_no_store()}];
}

sub import_no_consider
{
	my ($this) = @_;
	return ["passwd",@{$this->SUPER::import_no_consider()}];
}

1;
