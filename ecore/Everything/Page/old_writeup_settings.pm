package Everything::Page::old_writeup_settings;

use Moose;
extends 'Everything::Page::settings';

# Old Writeup Settings now uses the unified Settings interface
# The React component shows Display, Nodelets, and Advanced tabs
# This Page class exists so users going to "Old Writeup Settings" get the unified view
# (Previously this was a legacy settings page, now consolidated)

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Call parent to get the base data
  my $data = $self->SUPER::buildReactData($REQUEST);

  # Default to display tab (these were primarily display preferences)
  $data->{defaultTab} = 'display';

  return $data;
}

__PACKAGE__->meta->make_immutable;
1;
