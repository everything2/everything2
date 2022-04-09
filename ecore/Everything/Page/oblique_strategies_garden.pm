package Everything::Page::oblique_strategies_garden;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {};
}

__PACKAGE__->meta->make_immutable;

1;
