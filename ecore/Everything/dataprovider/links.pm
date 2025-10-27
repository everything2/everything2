package Everything::dataprovider::links;
use base qw(Everything::dataprovider::base);

use strict;
use warnings;
use lib qw(lib);

sub data_out
{
	my ($this, $nodeidhash) = @_;

	my $inclause = join(",",keys %$nodeidhash);

	my $linkcsr = $this->{dbh}->prepare("select * from links where to_node IN($inclause) and from_node IN($inclause)");
	$linkcsr->execute();
	my $data;
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
