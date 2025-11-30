package Everything::Controller::nodelet;

use Moose;
extends 'Everything::Controller';

# Nodelet Controller
#
# Handles display of nodelet nodes (sidebar components) as system pages.
# Nodelets are internal configuration nodes that define sidebar widgets.
# These nodes use the generic system_node React component.
#
# buildNodeInfoStructure() in Application.pm automatically creates
# the contentData with type=system_node for nodelet nodes.
#
# This replaces the legacy nodelet_display_page htmlpage function
# which used insertNodelet() to render nodelet content.

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $user = $REQUEST->user;

  # Nodelet nodes are only viewable by logged-in users
  # Guest users shouldn't see nodelet source/configuration
  if ($user->is_guest)
  {
    return [$self->HTTP_FOUND, '', {Location => '/title/Login'}];
  }

  # Use react_page layout - buildNodeInfoStructure() handles contentData
  my $html = $self->layout('/pages/react_page', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
