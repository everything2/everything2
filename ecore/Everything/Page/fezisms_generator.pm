package Everything::Page::fezisms_generator;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {};
}

__PACKAGE__->meta->make_immutable;

1;
