package Everything::Page::is_it_april_fools_day_yet;

use Moose;
extends 'Everything::Page';

has 'template' => (is => 'ro', default => 'is_it_holiday');

sub display
{
  my ($self, $REQUEST, $node) = @_;
  return {occasion => 'afd'};
}

__PACKAGE__->meta->make_immutable;

1;


