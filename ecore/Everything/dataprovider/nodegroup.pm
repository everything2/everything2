#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(lib);
use Everything::dataprovider::base;
package Everything::dataprovider::nodegroup;
use base qw(Everything::dataprovider::base);

sub data_out
{
	my ($this, $nodeidhash) = @_;

	my $inclause = join(",",keys %$nodeidhash);

	my $linkcsr = $this->{dbh}->prepare("select * from nodegroup where nodegroup_id IN($inclause) and node_id IN($inclause)");
	$linkcsr->execute();
	my $data = {"group" => []};
	while(my $row = $linkcsr->fetchrow_hashref())
	{
		push @{$data->{group}}, $row;
	}

	return $this->SUPER::xml_out($data);
}

sub data_in
{
	my ($this, $xml) = @_;
	my $data = $this->{xs}->XMLin($xml);
	foreach my $link (@{$data->{nodegroup}->{group}})
	{
		$this->_hash_insert("nodegroup",$link);
	}
	return;
}

1;
