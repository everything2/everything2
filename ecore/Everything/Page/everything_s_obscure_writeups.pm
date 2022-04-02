package Everything::Page::everything_s_obscure_writeups;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub display
{
  my ($self, $REQUEST) = @_;

  return {nodes => $self->APP->obscure_writeups}

}

__PACKAGE__->meta->make_immutable;

1;
