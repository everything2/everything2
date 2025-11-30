package Everything::Page::e2_full_text_search;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    type => 'full_text_search',
    cseId => '017923811620760923756:pspyfx78im4',
    nodeId => $REQUEST->node->node_id
  };
}

__PACKAGE__->meta->make_immutable;

1;
