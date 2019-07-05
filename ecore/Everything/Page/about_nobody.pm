package Everything::Page::about_nobody;

use Moose;
extends 'Everything::Page';

sub display
{
  return {};
}

__PACKAGE__->meta->make_immutable;

1;
