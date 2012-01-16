#!/usr/bin/perl -w

use strict;
use lib qw(lib);
use Clone qw(clone);
package Everything::node::dbtable;
use Everything::node::node;
use base qw(Everything::node::node);

sub node_to_xml
{
	my ($this, $N) = @_;
	my $NODE = Clone::clone($N);

	my $create_table_statement = `mysqldump --skip-add-drop-table --skip-add-locks --skip-disable-keys --skip-set-charset --skip-comments -d -u everything everything $$NODE{title}`;
	if(not defined($create_table_statement))
	{
		die "Could not get create table statement for dbtable $$NODE{title}";
	}

	$NODE->{_create_table_statement} = $create_table_statement;
	return $this->SUPER::node_to_xml($NODE);
}

sub xml_to_node_post
{
	my ($this, $N) = @_;
	delete $N->{_create_table_statement};
	return $N;
}

1;
