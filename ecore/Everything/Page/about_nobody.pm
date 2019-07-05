package Everything::Page::about_nobody;

use Moose;
extends 'Everything::Page';

sub display
{
  return {};
}

1;

__PACKAGE__->meta->make_immutable;
