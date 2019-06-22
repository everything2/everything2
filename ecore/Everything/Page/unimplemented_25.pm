package Everything::Page::25;

use Moose;
extends 'Everything::Page';

has 'records' => (is => 'ro', isa => 'Int', default => 25);

sub display
{
  my ($self, $REQUEST, $node) = @_; 
  return {nodelist => $self->APP->newnodes($self->records)}; 
}

1;

__PACKAGE__->meta->make_immutable;
