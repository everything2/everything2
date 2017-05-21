package Everything::Controller::maintenance;

use Moose;
extends 'Everything::Controller::node';

sub display
{
  my ($self, $REQUEST, $node) = @_;
  my $html = $self->layout('/maintenance_display', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK,$html];
}

1;
