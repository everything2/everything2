package Everything::DataStash::editing_null_node_titles;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 86400); #24h
has '+lengthy' => (default => 1);


sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("node_id","node","title is null");

  my $outdata = [];
  while (my $row = $csr->fetchrow_arrayref)
  {
    push @$outdata, $row->[0];
  }

  return $this->SUPER::generate($outdata);
}


__PACKAGE__->meta->make_immutable;
1;
