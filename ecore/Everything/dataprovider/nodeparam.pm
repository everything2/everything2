package Everything::dataprovider::nodeparam;
use base qw(Everything::dataprovider::base);

use strict;
use warnings;
use lib qw(lib);

sub data_out
{
	my ($this, $nodeidhash) = @_;

	# Fixed SQL injection: validate node IDs as integers and use placeholders
	my @node_ids = keys %{$nodeidhash};
	my $data = {nodeparam => []};

	# Validate all node IDs are integers
	foreach my $id (@node_ids) {
		die "Invalid node ID: $id" unless $id =~ /^\d+$/;
	}

	# Return empty result if no node IDs provided
	return $this->SUPER::xml_out($data) if scalar(@node_ids) == 0;

	# Build placeholders for prepared statement
	my $placeholders = join(",", ("?") x scalar(@node_ids));

	my $csr = $this->{dbh}->prepare(
		"SELECT * FROM nodeparam WHERE node_id IN($placeholders)"
	);
	$csr->execute(@node_ids);
	while(my $row = $csr->fetchrow_hashref())
	{
		next if $row->{paramkey} eq "last_update";
		push @{$data->{nodeparam}}, $row;
	}

	return $this->SUPER::xml_out($data);
}

sub data_in
{
	my ($this, $xml) = @_;
	my $data = $this->{xs}->XMLin($xml);
	foreach my $nodeparam (@{$data->{nodeparam}->{nodeparam}})
	{
		$this->_hash_insert("nodeparam",$nodeparam);
	}
	return;
}

1;
