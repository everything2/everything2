package Everything::Page::node_tracker2;

use Moose;
extends 'Everything::Page';

with 'Everything::Security::NoGuest';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  return [$self->HTTP_OK, "testing"];
}

__PACKAGE__->meta->make_immutable;

1;
