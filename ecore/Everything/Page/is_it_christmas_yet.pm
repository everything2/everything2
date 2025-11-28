package Everything::Page::is_it_christmas_yet;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    occasion => 'xmas'
  };
}

__PACKAGE__->meta->make_immutable;

1;


