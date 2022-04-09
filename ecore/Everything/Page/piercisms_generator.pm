package Everything::Page::piercisms_generator;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {};
}

__PACKAGE__->meta->make_immutable;

1;
