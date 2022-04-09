package Everything::Page::is_it_new_year_s_eve_yet;

use Moose;
extends 'Everything::Page';

has 'template' => (is => 'ro', default => 'is_it_holiday');

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {occasion => 'nye'};
}

__PACKAGE__->meta->make_immutable;

1;


