package Everything::dataprovider::nodeparam;
use base qw(Everything::dataprovider::base);

use strict;
use warnings;
use lib qw(lib);

sub data_out
{
	my ($this, $nodeidhash) = @_;

	my $inclause = join(",",keys %$nodeidhash);

	my $csr = $this->{dbh}->prepare("select * from nodeparam where node_id IN($inclause)");
	$csr->execute();
	my $data;
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
