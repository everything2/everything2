package Everything::Page::everything2_elsewhere;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $maintainer = $self->APP->node_by_name('root','user');

  if(!$self->APP->inDevEnvironment)
  {
    $maintainer = $self->APP->node_by_name('Oolong','user');
  }

  return {
    maintainer => {
      node_id => $maintainer->id,
      title => $maintainer->title
    }
  };
}

__PACKAGE__->meta->make_immutable;

1;
