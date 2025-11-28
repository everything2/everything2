package Everything::Page::is_it_april_fools_day_yet;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    occasion => 'afd'
  };
}

__PACKAGE__->meta->make_immutable;

1;


