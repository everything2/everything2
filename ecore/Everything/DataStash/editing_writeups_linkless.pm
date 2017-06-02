package Everything::DataStash::editing_writeups_linkless;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 86400); #24h
has '+lengthy' => (default => 1);


sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("n.node_id","node n left join document d on n.node_id=d.document_id","n.type_nodetype=".$this->DB->getType("writeup")->{node_id}." and n.author_user !=".$this->DB->getNode("Webster 1913","user")->{node_id}." and d.doctext not like '%[%' and createtime > '2001-01-01' limit 200");

  my $outdata = [];
  while (my $row = $csr->fetchrow_arrayref)
  {
    push @$outdata, $row->[0];
  }

  return $this->SUPER::generate($outdata);
}


__PACKAGE__->meta->make_immutable;
1;
