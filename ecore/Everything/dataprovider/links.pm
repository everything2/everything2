package Everything::dataprovider::links;
use base qw(Everything::dataprovider::base);

use strict;
use warnings;
use lib qw(lib);

sub data_out
{
	my ($this, $nodeidhash) = @_;

	# Fixed SQL injection: validate node IDs as integers and use placeholders
	my @node_ids = keys %{$nodeidhash};
	my $data = {link => []};

	# Validate all node IDs are integers
	foreach my $id (@node_ids) {
		die "Invalid node ID: $id" unless $id =~ /^\d+$/;
	}

	# Return empty result if no node IDs provided
	return $this->SUPER::xml_out($data) if scalar(@node_ids) == 0;

	# Build placeholders for prepared statement
	my $placeholders = join(',', ('?') x scalar(@node_ids));

	my $linkcsr = $this->{dbh}->prepare(
		"SELECT * FROM links WHERE to_node IN($placeholders) AND from_node IN($placeholders)"
	);
	$linkcsr->execute(@node_ids, @node_ids);

	while(my $row = $linkcsr->fetchrow_hashref())
	{
		push @{$data->{link}}, $row;
	}

	return $this->SUPER::xml_out($data);
}

sub data_in
{
	my ($this, $xml) = @_;
	my $data = $this->{xs}->XMLin($xml);
	foreach my $link (@{$data->{links}->{link}})
	{
		$this->_hash_insert("links",$link);
	}
	return;
}

1;
