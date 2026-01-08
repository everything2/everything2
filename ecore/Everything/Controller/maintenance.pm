package Everything::Controller::maintenance;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Maintenance Controller
#
# Handles display and editing of maintenance nodes.
# Maintenance nodes define automated operations on node types
# (create, update, delete operations).

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $user = $REQUEST->user;
  my $APP = $REQUEST->APP;
  my $node_data = $node->NODEDATA;

  # Maintenance nodes are only viewable by staff, developers, or admins
  unless ($user->is_editor || $user->is_developer || $user->is_admin)
  {
    return [$self->HTTP_FOUND, '', {Location => '/title/Permission+Denied'}];
  }

  # Get the nodetype this maintenance operates on
  my $maintain_nodetype_title;
  if ($node_data->{maintain_nodetype}) {
    my $nodetype_node = $APP->node_by_id($node_data->{maintain_nodetype});
    $maintain_nodetype_title = $nodetype_node->{title} if $nodetype_node;
  }

  # Get code preview (first 2000 chars)
  my $code_preview;
  if ($node_data->{code}) {
    $code_preview = length($node_data->{code}) > 2000
      ? substr($node_data->{code}, 0, 2000) . "\n... (truncated)"
      : $node_data->{code};
  }

  # Check if this maintenance is delegated
  my $is_delegated = $self->_is_delegated($node->title);

  # Build user data
  my $user_data = {
    node_id   => $user->node_id,
    title     => $user->title,
    is_guest  => $user->is_guest  ? 1 : 0,
    is_editor => $user->is_editor ? 1 : 0
  };

  # Build source map for maintenance
  my $source_map = {
    githubRepo => 'https://github.com/everything2/everything2',
    branch     => 'master',
    commitHash => $self->APP->{conf}->last_commit || 'master',
    components => [
      {
        type        => 'controller',
        name        => 'Everything::Controller::maintenance',
        path        => 'ecore/Everything/Controller/maintenance.pm',
        description => 'Controller for maintenance display'
      },
      {
        type        => 'react_document',
        name        => 'Maintenance',
        path        => 'react/components/Documents/Maintenance.js',
        description => 'React document component for maintenance display'
      }
    ]
  };

  # Add delegation module if this maintenance is delegated
  if ($is_delegated) {
    push @{$source_map->{components}}, {
      type        => 'delegation',
      name        => 'Everything::Delegation::maintenance',
      path        => 'ecore/Everything/Delegation/maintenance.pm',
      description => 'Delegated maintenance implementations'
    };
  }

  # Build contentData for React
  my $content_data = {
    type => 'maintenance',
    maintenance => {
      node_id => $node_data->{node_id},
      title => $node_data->{title},
      type => 'maintenance',
      type_nodetype => $node_data->{type_nodetype},
      maintain_nodetype => $node_data->{maintain_nodetype},
      maintain_nodetype_title => $maintain_nodetype_title,
      maintaintype => $node_data->{maintaintype},
      code_preview => $code_preview,
      is_delegated => $is_delegated ? 1 : 0,
      createtime => $node_data->{createtime}
    },
    user      => $user_data,
    sourceMap => $source_map
  };

  # Set node on REQUEST for buildNodeInfoStructure
  $REQUEST->node($node);

  # Build e2 data structure
  my $e2 = $self->APP->buildNodeInfoStructure(
    $node_data,
    $REQUEST->user->NODEDATA,
    $REQUEST->user->VARS,
    $REQUEST->cgi,
    $REQUEST
  );

  # Override contentData with our directly-built data
  $e2->{contentData}   = $content_data;
  $e2->{reactPageMode} = \1;

  # Use react_page layout
  my $html = $self->layout(
    '/pages/react_page',
    e2      => $e2,
    REQUEST => $REQUEST,
    node    => $node
  );
  return [$self->HTTP_OK, $html];
}

# Check if this maintenance node has a delegated implementation
sub _is_delegated
{
  my ($self, $title) = @_;

  my $sub_name = $title;
  $sub_name =~ s/\s+/_/g;

  # Check if the sub exists using can()
  return Everything::Delegation::maintenance->can($sub_name) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;
1;
