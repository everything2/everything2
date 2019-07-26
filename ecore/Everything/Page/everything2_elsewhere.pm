package Everything::Page::everything2_elsewhere;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self) = @_;

  my $maintainer = $self->APP->node_by_name('root','user');

  if(!$self->APP->inDevEnvironment)
  {
    $maintainer = $self->APP->node_by_name('Oolong','user');
  }
  return {maintainer => $maintainer};
}

__PACKAGE__->meta->make_immutable;

1;
