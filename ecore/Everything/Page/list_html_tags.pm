package Everything::Page::list_html_tags;

use Moose;
extends 'Everything::Page';

# Mason2 template removed - page now uses React via buildReactData()
sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $approved_tags = $self->APP->node_by_name('approved html tags', 'setting')->VARS;

  return {
    type => 'list_html_tags',
    approvedTags => $approved_tags
  };
}

__PACKAGE__->meta->make_immutable;

1;
