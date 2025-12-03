package Everything::Page::nodelet_settings;

use Moose;
extends 'Everything::Page::settings';

# Nodelet Settings now uses the unified Settings interface
# The React component shows Display, Nodelets, and Advanced tabs
# This Page class exists so users going to "Nodelet Settings" get the unified view
# with the Nodelets tab active by default

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Call parent to get the base data
  my $data = $self->SUPER::buildReactData($REQUEST);

  # Override defaultTab to show Nodelets tab for Nodelet Settings page
  $data->{defaultTab} = 'nodelets';

  return $data;
}

__PACKAGE__->meta->make_immutable;
1;
