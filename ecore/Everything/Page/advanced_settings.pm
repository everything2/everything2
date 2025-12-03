package Everything::Page::advanced_settings;

use Moose;
extends 'Everything::Page::settings';

# Advanced Settings now uses the unified Settings interface
# The React component shows Display, Nodelets, and Advanced tabs
# This Page class exists so users going to "Advanced Settings" get the unified view
# with the Advanced tab active by default

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Call parent to get the base data
  my $data = $self->SUPER::buildReactData($REQUEST);

  # Override defaultTab to show Advanced tab for Advanced Settings page
  $data->{defaultTab} = 'advanced';

  return $data;
}

__PACKAGE__->meta->make_immutable;
1;
