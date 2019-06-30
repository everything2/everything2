package Everything::Page::list_html_tags;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $approved_tags = $self->APP->node_by_name('approved HTML tags','setting')->VARS;
  return {approved_tags => $approved_tags};
}

1;

__PACKAGE__->meta->make_immutable;
