package Everything::DataStash::editing_writeups_under_20_characters;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 86400); #24h
has '+lengthy' => (default => 1);


sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("node_id","node left join document on node.node_id=document.document_id","LENGTH(doctext) < 20 and type_nodetype=".$this->DB->getType("writeup")->{node_id});

  my $outdata = [];
  while(my $row = $csr->fetchrow_arrayref)
  {
    push @$outdata, $row->[0];
  }

  return $this->SUPER::generate($outdata);
}


__PACKAGE__->meta->make_immutable;
1;
