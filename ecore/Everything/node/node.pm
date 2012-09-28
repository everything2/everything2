#!/usr/bin/perl -w

use strict;
use XML::Simple qw(:strict);
use Clone qw(clone);
package Everything::node::node;
use utf8;

sub new
{
	my ($class) = shift;
	my $this = {"xs" => XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "SuppressEmpty" => 1, "NumericEscape" => 2, "KeyAttr" => {}, "ForceArray" => ['vars'], "NoAttr" => 1)};
	return bless $this,$class;
}

sub node_xml_prep
{
	my ($this, $N, $dbh, $options) = @_;
	my $NODE = Clone::clone($N);
	
	$this->_node_xml_latin1_conversion($NODE);
	$this->_strip_defaults($NODE,$dbh);

	foreach my $field(@{$this->xml_no_store()})
	{
		delete $NODE->{$field};
	}

	return $NODE;
}

sub _node_xml_latin1_conversion
{
	my ($this, $NODE) = @_;

	foreach my $key (keys %$NODE)
	{
		next if not defined($NODE->{$key});
		next if $NODE->{$key} eq "";
		if(!utf8::is_utf8($NODE->{$key}))
		{
			utf8::decode($NODE->{$key});
		}
	}

	return $NODE;
}

sub node_to_xml
{
	my ($this, $N, $dbh, $options) = @_;
	my $NODE = $this->node_xml_prep($N, $dbh, $options);

	my $vars_out;
	if(exists($NODE->{vars}))
	{
		$vars_out = {Everything::getVarHashFromStringFast($NODE->{vars})};
		$NODE->{vars} = [];
		foreach my $key(keys %$vars_out)
		{
			next if(grep(/^$key$/, @{$this->xml_vars_no_store()}));
			push @{$NODE->{vars}},{"key" => $key, "value" => $vars_out->{$key}};
		}
	}

	return $this->{xs}->XMLout({node => $NODE});
}

sub xml_vars_no_store
{
	my ($this) = @_;
	return [];
}

sub xml_no_store
{
	my ($this) = @_;

	return ["core","hits","type","author_user","totalvotes","createtime",@{$this->node_id_equivs()}];
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
	die "Malformed XML, no <node> construct!\n" unless ref $NODE eq "HASH";
	$NODE = $NODE->{node};

	die "Malformed node construct, not a hash!\n".Data::Dumper->Dump([$NODE]) unless ref $NODE eq "HASH";

	foreach my $field (@{$this->node_id_equivs()})
	{
		$NODE->{$field} = $NODE->{node_id};
	}
	$NODE = $this->_repack_node_vars($NODE);
	return $this->xml_to_node_post($NODE);
}

sub _repack_node_vars
{
	my ($this, $NODE) = @_;

	return $NODE unless(exists($NODE->{vars}));
	# XML::Simple always packs vars into an array
	return $NODE unless ref $NODE->{vars} eq "ARRAY";
	my $vars_in;
	foreach my $varsitem (@{$NODE->{vars}})
	{
		next unless defined($varsitem->{key});
		$vars_in->{$varsitem->{key}} = $varsitem->{value};
	}
	$vars_in ||= {};

	$NODE->{vars} = Everything::getVarStringFromHash($vars_in);

	return $NODE;
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

	if(not defined($string))
	{
		return;
	}
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
				if(defined($row->{Default}) and defined($NODE->{$row->{Field}}) and ($NODE->{$row->{Field}} eq $row->{Default}))
				{
					delete $NODE->{$row->{Field}};
					#print STDERR "Stripped $$row{Field} from $$NODE{title}\n";
				}elsif(not defined($row->{Default}) and not defined($NODE->{$row->{Field}}))
				{
					delete $NODE->{$row->{Field}};
				}
			}

			
		}
	}
}

sub import_no_consider
{
	my ($this) = @_;
	return ["node_id"];
}

sub import_skip_update
{
	my ($this) = @_;
	return [];
}

sub never_export
{
	my ($this) = @_;
	return [];
}

1;
