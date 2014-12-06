package Everything::DataStash::staffpicks;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $limit = 15;

  my $cuss = $this->DB->sqlSelectMany( 'from_node'
    , 'links JOIN node ON node.node_id = links.from_node'
    , "linktype = ".$this->DB->getId($this->DB->getNode('coollink','linktype'))
    . " AND node.type_nodetype = " . $this->DB->getId($this->DB->getNode('e2node','nodetype'))
    . " ORDER BY rand() LIMIT $limit"
  );

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
