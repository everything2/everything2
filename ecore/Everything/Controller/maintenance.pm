package Everything::Controller::maintenance;

use Moose;
extends 'Everything::Controller';

# Maintenance Controller
#
# Handles display of maintenance nodes (internal code/config nodes).
# These nodes use the generic system_node React component.
#
# buildNodeInfoStructure() in Application.pm automatically creates
# the contentData with type=system_node for maintenance nodes.

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $user = $REQUEST->user;

  # Maintenance nodes are only viewable by staff, developers, or admins
  # This allows developers to see the source map and code trace
  unless ($user->is_editor || $user->is_developer || $user->is_admin)
  {
    # Redirect to Permission Denied page
    # mod_perl won't display body text on 403, so we redirect instead
    return [$self->HTTP_FOUND, '', {Location => '/title/Permission+Denied'}];
  }

  # Use react_page layout - buildNodeInfoStructure() handles contentData
  my $html = $self->layout('/pages/react_page', REQUEST => $REQUEST, node => $node);
  return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
