package Everything::Page::unimplemented_25;

use Moose;
extends 'Everything::Page';

has 'records' => (is => 'ro', isa => 'Int', default => 25);

sub display
{
  my ($self, $REQUEST, $node) = @_; 
  return {nodelist => $self->APP->newnodes($self->records)}; 
}

__PACKAGE__->meta->make_immutable;

1;
