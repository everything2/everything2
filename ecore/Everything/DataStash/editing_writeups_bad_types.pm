package Everything::DataStash::editing_writeups_bad_types;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 86400); #24h
has '+lengthy' => (default => 1);


sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("n.node_id","node n left join writeup w on n.node_id=w.writeup_id","n.type_nodetype=".$this->DB->getType("writeup")->{node_id}." and NOT EXISTS (SELECT node_id from node where node_id=w.wrtype_writeuptype)");

  my $outdata = [];
  while (my $row = $csr->fetchrow_arrayref)
  {
    push @$outdata, $row->[0];
  }

  return $this->SUPER::generate($outdata);
}


__PACKAGE__->meta->make_immutable;
1;
