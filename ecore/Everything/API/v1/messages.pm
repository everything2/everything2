package Everything::API::v1::messages;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub get
{
  my ($self, $REQUEST) = @_;
  if($self->APP->isGuest($REQUEST->USER))
  {
    return [$self->HTTP_FORBIDDEN];
  }
  return [200, {}];
}

__PACKAGE__->meta->make_immutable;
1;
