package Everything::Page::nodeshells;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my @nodeshells;

  my $csr = $self->DB->sqlSelectMany('node.node_id',
    "node JOIN e2node ON node_id=e2node_id LEFT JOIN nodegroup ON nodegroup_id = node.node_id",
    "node.createtime > DATE_SUB(CURDATE(), INTERVAL 1 WEEK)
    AND node.createtime < DATE_SUB(CURDATE(), INTERVAL 30 MINUTE)
    AND node.type_nodetype=116 AND nodegroup_id IS NULL ORDER BY node_id DESC LIMIT 50");

  while(my $row = $csr->fetchrow_hashref)
  {
    my $node = $self->APP->node_by_id($row->{node_id});
    if(defined($node))
    {
      push @nodeshells, {
        node_id => $node->node_id,
        title => $node->title,
        createtime => $node->createtime
      };
    }
  }

  return {
    type => 'nodeshells',
    nodeshells => \@nodeshells
  };
}

__PACKAGE__->meta->make_immutable;

1;
