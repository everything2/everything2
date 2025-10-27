package Everything::Controller::fullpage;

use Moose;
extends 'Everything::Controller::page';

# TODO: Wind this type down

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return $self->page_delegate($REQUEST,$node);
}

__PACKAGE__->meta->make_immutable();
1;
