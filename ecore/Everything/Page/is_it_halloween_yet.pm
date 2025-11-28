package Everything::Page::is_it_halloween_yet;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    occasion => 'halloween'
  };
}

__PACKAGE__->meta->make_immutable;

1;


