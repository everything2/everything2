package Everything::DataStash::newwriteups;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;
  my $howMany = 100;

  my $cuss = $this->DB->sqlSelectMany('
    writeup_id, parent_e2node, notnew,
    node.author_user, node.reputation,
    type.title AS type_title,
    node.title REGEXP
      \'^((January|February|March|April|May|June|July|August|September|October'
      .'|November|December) [[:digit:]]{1,2}, [[:digit:]]{4})'
      .'|((dream|editor|root) Log: )\'
    AS islog ','
    writeup JOIN node ON writeup_id = node.node_id JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
    'node.author_user != ' .$this->DB->getNode('Webster 1913' , 'user') -> {node_id},
    "ORDER BY publishtime DESC LIMIT $howMany");

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
