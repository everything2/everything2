package Everything::Page::online_only_msg;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Content-only component - uses global user prop from PageLayout
  return {};
}

__PACKAGE__->meta->make_immutable;

1;
