package Everything::Page::kaizen_ui_preview;

use Moose;
use namespace::autoclean;
extends 'Everything::Page';

sub display
{
  my ($self) = @_;
  return [$self->HTTP_OK, $self->MASON->run('/kaizen')->output()];
}

__PACKAGE__->meta->make_immutable;
1;
