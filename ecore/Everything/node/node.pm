#!/usr/bin/perl -w

use strict;
use XML::Simple;
use Clone qw(clone);
package Everything::node::node;

sub new
{
	my ($class) = shift;
	my $this = {"xs" => XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1,"SuppressEmpty" => "", "NumericEscape" => 2)};
	return bless $this,$class;
}

sub node_xml_prep
{
	my ($this, $N, $dbh, $options) = @_;
	my $NODE = Clone::clone($N);
	
	$this->_strip_defaults($NODE,$dbh);
	foreach my $field(@{$this->xml_no_consider()})
	{
		delete $NODE->{$field};
	}

	return $NODE;
}

sub node_to_xml
{
	my ($this, $N, $dbh, $options) = @_;
	my $NODE = $this->node_xml_prep($N, $dbh, $options);

	return $this->{xs}->XMLout({node => $NODE});
}

sub xml_no_consider
{
	my ($this) = @_;

	return ["_ORIGINAL_VALUES", "core","hits","type","author_user","totalvotes","createtime",@{$this->node_id_equivs()}];
}

sub node_id_equivs
{
	my ($this) = @_;
	return [];
}

sub xml_to_node
{
	my ($this, $xml) = @_;
	
	my $NODE = $this->{xs}->XMLin($xml);
	$NODE = $NODE->{node};

	foreach my $field (@{$this->node_id_equivs()})
	{
		$NODE->{$field} = $NODE->{node_id};
	}
	return $this->xml_to_node_post($NODE);
}

sub xml_to_node_post
{
	my ($this, $N) = @_;
	
	# The uid for root
	$N->{author_user} = 113;
	$N->{totalvotes} = 0;
	return $N;
}

sub _clean_code
{
	my ($this, $string) = @_;

	# Remove old windows line endings
	$string =~ s|\r\n|\n|g;
	# Remove a bad control character found in the code
	$string =~ s|\cC||g;
	return $string;
}

sub _strip_defaults
{
	my ($this, $NODE, $dbh) = @_;

	if(not defined($NODE->{type}->{tableArray}))
	{
		print STDERR "Missing internal table array construct!\n";
		exit;
	}

	if(not defined($dbh))
	{
		print STDERR "No database handle for _strip_defaults in node $$NODE{title}\n";
		return;
	}

	foreach my $table("node",@{$NODE->{type}->{tableArray}})
	{
		my $csr = $dbh->prepare("EXPLAIN $table");

		if(not defined $csr)
		{
			print STDERR "Could not explain table: $table in node $$NODE{title}\n";
			next;
		}

		$csr->execute();
		while(my $row = $csr->fetchrow_hashref())
		{
			if(exists($NODE->{$row->{Field}}))
			{
				if(defined($row->{Default}) and $NODE->{$row->{Field}} eq $row->{Default} and $row->{Default} ne "NULL")
				{
					delete $NODE->{$row->{Field}};
					#print STDERR "Stripped $$row{Field} from $$NODE{title}\n";
				}
			}
		}
	}
}

1;
