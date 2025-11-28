package Everything::Page::is_it_new_year_s_eve_yet;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    occasion => 'nye'
  };
}

__PACKAGE__->meta->make_immutable;

1;


