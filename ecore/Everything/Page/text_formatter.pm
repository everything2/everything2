package Everything::Page::text_formatter;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    type => 'text_formatter'
  };
}

__PACKAGE__->meta->make_immutable;

1;
