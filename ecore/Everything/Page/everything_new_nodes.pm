package Everything::Page::everything_new_nodes;

use Moose;
extends 'Everything::Page';

has 'template' => (is => 'ro', default => 'numbered_nodelist');
has 'records' => (is => 'ro', isa => 'Int', default => 100);

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {nodelist => $self->APP->newnodes($self->records, $REQUEST->user->is_editor)};
}

__PACKAGE__->meta->make_immutable;

1;
