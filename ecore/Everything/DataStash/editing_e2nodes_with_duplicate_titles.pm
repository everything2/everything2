package Everything::DataStash::editing_e2nodes_with_duplicate_titles;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 86400); #24h
has '+lengthy' => (default => 1);


sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("c.node_id as node_id","(select node_id,title,(select count(distinct(LOWER(title))) from node where title=n.title) collisions from node n where type_nodetype=116) c","c.collisions > 1");

  my $outdata = [];
  while (my $row = $csr->fetchrow_arrayref)
  {
    push @$outdata, $row->[0];
  }

  return $this->SUPER::generate($outdata);
}


__PACKAGE__->meta->make_immutable;
1;
