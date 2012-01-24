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

sub node_to_xml
{
	my ($this, $N, $dbh) = @_;
	my $NODE = Clone::clone($N);

	$NODE->{hits} = 0;
	
	delete $NODE->{_ORIGINAL_VALUES};
	delete $NODE->{resolvedInheritance};

	$this->_strip_defaults($NODE,$dbh);
	delete $NODE->{sqltablelist};
	delete $NODE->{type};
	delete $NODE->{tableArray};
	
	return $this->{xs}->XMLout({node => $NODE});
}

sub xml_to_node
{
	my ($this, $xml) = @_;
	
	my $NODE = $this->{xs}->XMLin($xml);
	$NODE = $NODE->{node};
	return $this->xml_to_node_post($NODE);
}

sub xml_to_node_post
{
	my ($this, $N) = @_;
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
