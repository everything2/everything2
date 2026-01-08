package Everything::API::nodegroups;

use Moose;
extends 'Everything::API::nodes';

# Nodegroup API - Admin-only group management for generic nodegroups
#
# Unlike usergroups, nodegroups:
# - Can contain ANY node type (not just users/usergroups)
# - Are only editable by admins (no owner concept)
# - Return full type info for each member (for icon display)

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{':id/action/addnode'} = 'addnode(:id)';
  $routes->{':id/action/removenode'} = 'removenode(:id)';
  $routes->{':id/action/reorder'} = 'reorder(:id)';

  return $routes;
};

# Build enhanced member data with type info for icons
sub _build_enhanced_group
{
  my ($self, $group) = @_;

  my @enhanced_members;

  # Get current members from the group
  my $members = $group->NODEDATA->{group} || [];

  foreach my $member_id (@$members) {
    my $member = $self->APP->node_by_id($member_id);
    next unless $member;

    my $member_data = $member->NODEDATA;
    my $type_title = $member->type->title;

    # Build member info with type for icons
    my $member_info = {
      node_id => int($member_id),
      title => $member->title,
      type => $type_title
    };

    # Add author info if available (for documents, writeups, etc.)
    if ($member_data->{author_user}) {
      my $author = $self->APP->node_by_id($member_data->{author_user});
      if ($author) {
        $member_info->{author} = {
          node_id => int($author->node_id),
          title => $author->title
        };
      }
    }

    push @enhanced_members, $member_info;
  }

  return \@enhanced_members;
}

# Check if user can manage the nodegroup (admin only)
sub _can_manage_nodegroup
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;

  # Guests cannot manage
  if ($user->is_guest) {
    return [0, $self->HTTP_FORBIDDEN];
  }

  # Get the nodegroup
  my $group = $self->APP->node_by_id($id);
  unless ($group && $group->type->title eq 'nodegroup') {
    return [0, $self->HTTP_NOT_FOUND];
  }

  # Only admins can manage nodegroups
  unless ($user->is_admin) {
    return [0, $self->HTTP_FORBIDDEN];
  }

  return [1, $group, $user];
}

# Permission wrapper for add/remove operations
sub _group_operation_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_manage_nodegroup($REQUEST, $id);
  unless ($output->[0]) {
    return [$self->HTTP_OK, { success => 0, error => 'Permission denied' }];
  }
  my ($node, $user) = ($output->[1], $output->[2]);

  my $data = $REQUEST->JSON_POSTDATA;

  unless(ref $data eq 'HASH' && ref $data->{node_ids} eq 'ARRAY')
  {
    # Expecting POST to be { node_ids: [...] }
    return [$self->HTTP_OK, { success => 0, error => 'Expected { node_ids: [...] }' }];
  }

  return $self->$orig($user, $node, $data->{node_ids});
}

sub addnode
{
  my ($self, $user, $group, $node_ids) = @_;

  # Get current group members to avoid duplicates
  my %current_members = map { $_ => 1 } @{$group->NODEDATA->{group} || []};

  my @added;

  foreach my $item_id (@{$node_ids}) {
    next if $current_members{$item_id};

    # Verify the item exists
    my $item = $self->APP->node_by_id($item_id);
    unless ($item) {
      next;
    }

    # Insert directly into nodegroup table
    my $rank = $self->DB->sqlSelect('MAX(nodegroup_rank)', 'nodegroup',
      'nodegroup_id=' . $group->node_id) // -1;
    $rank++;

    $self->DB->sqlInsert('nodegroup', {
      nodegroup_id => $group->node_id,
      nodegroup_rank => $rank,
      node_id => $item_id,
      orderby => 0
    });

    push @added, $item_id;
  }

  # Refresh and return updated group
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    added => \@added,
    group => $self->_build_enhanced_group($group)
  }];
}

sub removenode
{
  my ($self, $user, $group, $node_ids) = @_;

  my @removed;

  foreach my $item_id (@{$node_ids}) {
    # Remove directly from nodegroup table
    $self->DB->sqlDelete('nodegroup',
      'nodegroup_id=' . $group->node_id . ' AND node_id=' . $item_id);
    push @removed, $item_id;
  }

  # Refresh and return updated group
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    removed => \@removed,
    group => $self->_build_enhanced_group($group)
  }];
}

# Permission wrapper for reorder operation
sub _reorder_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_manage_nodegroup($REQUEST, $id);
  unless ($output->[0]) {
    return [$self->HTTP_OK, { success => 0, error => 'Permission denied' }];
  }
  my ($node, $user) = ($output->[1], $output->[2]);

  my $data = $REQUEST->JSON_POSTDATA;

  unless(ref $data eq 'ARRAY')
  {
    return [$self->HTTP_OK, { success => 0, error => 'Expected array of node IDs' }];
  }

  return $self->$orig($user, $node, $data);
}

sub reorder
{
  my ($self, $user, $group, $new_order) = @_;

  # Validate that all IDs in new_order are currently in the group
  my %current_members = map { $_ => 1 } @{$group->NODEDATA->{group} || []};
  foreach my $id (@{$new_order}) {
    unless ($current_members{$id}) {
      return [$self->HTTP_OK, { success => 0, error => "Node $id is not in this group" }];
    }
  }

  my $group_id = $group->node_id;

  # Delete all current members from nodegroup table
  $self->DB->sqlDelete('nodegroup', "nodegroup_id=$group_id");

  # Re-insert in the new order
  my $rank = 0;
  foreach my $item_id (@{$new_order}) {
    $self->DB->sqlInsert('nodegroup', {
      nodegroup_id => $group_id,
      nodegroup_rank => $rank,
      node_id => $item_id,
      orderby => 0
    });
    $rank++;
  }

  # Refresh and return updated group
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    group => $self->_build_enhanced_group($group)
  }];
}

around ['addnode', 'removenode'] => \&_group_operation_permissions;
around ['reorder'] => \&_reorder_permissions;

__PACKAGE__->meta->make_immutable;
1;
