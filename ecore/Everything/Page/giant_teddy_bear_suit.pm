package Everything::Page::giant_teddy_bear_suit;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    type => 'giant_teddy_bear_suit'
  };
}

__PACKAGE__->meta->make_immutable;

1;
