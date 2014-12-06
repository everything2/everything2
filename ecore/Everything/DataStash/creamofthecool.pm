package Everything::DataStash::creamofthecool;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

my $repthreshholdlo = 12;
my $repthreshholdhi = 20;
my $limit = 4;

my $cuss = $this->DB->sqlSelectMany(
  'wu.node_id, wu.author_user,
    parent_e2node,
    doctext,
    type.title as type_title',
  'node wu
    JOIN writeup ON writeup_id= wu.node_id 
    JOIN document on document_id = wu.node_id
    JOIN node type on type.node_id = writeup.wrtype_writeuptype',
  "wu.reputation > $repthreshholdlo
    AND wu.reputation < $repthreshholdhi
    AND writeup.cooled != 0",
  "ORDER BY writeup.publishtime DESC LIMIT $limit"
);

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
