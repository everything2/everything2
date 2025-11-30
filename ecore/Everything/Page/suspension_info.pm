package Everything::Page::suspension_info;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    type => 'suspension_info'
  };
}

__PACKAGE__->meta->make_immutable;

1;
