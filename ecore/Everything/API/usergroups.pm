package Everything::API::usergroups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);
has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{':id/action/adduser'} = 'adduser(:id)';
  $routes->{':id/action/removeuser'} = 'removeuser(:id)';
  $routes->{':id/action/leave'} = 'leave(:id)';
  $routes->{':id/action/reorder'} = 'reorder(:id)';
  $routes->{':id/action/description'} = 'update_description(:id)';
  $routes->{':id/action/transfer_ownership'} = 'transfer_ownership(:id)';
  $routes->{':id/action/weblogify'} = 'weblogify(:id)';

  return $routes;
};

# Build enhanced member data with flags, is_owner, is_current
# This mirrors what the controller does for initial page render
sub _build_enhanced_group
{
  my ($self, $group, $user) = @_;

  my $owner_id = $self->APP->getParameter($group->NODEDATA, 'usergroup_owner') || 0;
  my $user_id = $user->node_id;
  my $group_title = $group->title;

  # Flags to show based on usergroup context
  my $show_admin_flag = ($group_title ne 'gods');
  my $show_ce_flag = ($group_title ne 'Content Editors');

  my @enhanced_members;

  # Refresh the group to get current members
  my $members = $group->NODEDATA->{group} || [];

  foreach my $member_id (@$members) {
    my $member = $self->APP->node_by_id($member_id);
    next unless $member;

    my $member_ref = $member->json_reference;

    # Build flags string
    my $flags = '';
    if ($show_admin_flag) {
      if ($self->APP->isAdmin($member_id)
          && !$self->APP->getParameter($member_id, "hide_chatterbox_staff_symbol")) {
        $flags .= '@';
      }
    }

    if ($show_ce_flag) {
      if ($self->APP->isEditor($member_id, "nogods")
          && !$self->APP->isAdmin($member_id)
          && !$self->APP->getParameter($member_id, "hide_chatterbox_staff_symbol")) {
        $flags .= '$';
      }
    }

    if ($show_admin_flag && $self->APP->isChanop($member_id, "nogods")) {
      $flags .= '+';
    }

    # Mark owner and current user
    my $is_owner = ($member_id == $owner_id) ? 1 : 0;
    my $is_current = ($member_id == $user_id) ? 1 : 0;

    push @enhanced_members, {
      %$member_ref,
      flags => $flags,
      is_owner => $is_owner,
      is_current => $is_current
    };
  }

  return \@enhanced_members;
}

# Check if user can manage the usergroup (admin, editor, or owner)
sub _can_manage_usergroup
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;

  # Guests cannot manage
  if ($user->is_guest) {
    return [0, $self->HTTP_FORBIDDEN];
  }

  # Get the usergroup
  my $group = $self->APP->node_by_id($id);
  unless ($group && $group->type->title eq 'usergroup') {
    return [0, $self->HTTP_NOT_FOUND];
  }

  # Admins can always manage
  if ($user->is_admin) {
    return [1, $group, $user];
  }

  # Editors can manage
  if ($user->is_editor) {
    return [1, $group, $user];
  }

  # Usergroup owners can manage their own group
  my $owner_id = $self->APP->getParameter($group->NODEDATA, 'usergroup_owner') || 0;
  if ($owner_id && $owner_id == $user->node_id) {
    return [1, $group, $user];
  }

  return [0, $self->HTTP_FORBIDDEN];
}

sub _group_operation_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_manage_usergroup($REQUEST, $id);
  unless ($output->[0]) {
    return [$output->[1]];
  }
  my ($node, $user) = ($output->[1], $output->[2]);

  my $data = $REQUEST->JSON_POSTDATA;

  unless(ref $data eq 'ARRAY')
  {
    # Expecting POST to be an array. Returning BAD REQUEST
    return [$self->BAD_REQUEST];
  }

  return $self->$orig($user, $node, $data);
}

sub adduser
{
  my ($self, $user, $group, $data) = @_;

  # Get current group members to avoid duplicates
  my %current_members = map { $_ => 1 } @{$group->NODEDATA->{group} || []};

  foreach my $item_id (@{$data}) {
    next if $current_members{$item_id};

    # Verify the item exists and is a user or usergroup
    my $item = $self->APP->node_by_id($item_id);
    next unless $item;
    my $item_type = $item->type->title;
    next unless $item_type eq 'user' || $item_type eq 'usergroup';

    # Insert directly into nodegroup table (bypassing canUpdateNode which checks author)
    my $rank = $self->DB->sqlSelect('MAX(nodegroup_rank)', 'nodegroup',
      'nodegroup_id=' . $group->node_id) // -1;
    $rank++;

    $self->DB->sqlInsert('nodegroup', {
      nodegroup_id => $group->node_id,
      nodegroup_rank => $rank,
      node_id => $item_id,
      orderby => 0
    });
  }

  # Refresh and return updated group with enhanced member data
  $group->cache_refresh;

  return [$self->HTTP_OK, { group => $self->_build_enhanced_group($group, $user) }];
}

sub removeuser
{
  my ($self, $user, $group, $data) = @_;

  # Check if owner is trying to remove themselves
  my $owner_id = $self->APP->getParameter($group->NODEDATA, 'usergroup_owner') || 0;

  foreach my $item_id (@{$data}) {
    # Prevent owner from removing themselves - they must transfer ownership first
    if ($owner_id && $item_id == $owner_id) {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'Cannot remove the group owner. Transfer ownership first.'
      }];
    }

    # Remove directly from nodegroup table
    $self->DB->sqlDelete('nodegroup',
      'nodegroup_id=' . $group->node_id . ' AND node_id=' . $item_id);
  }

  # Refresh and return updated group with enhanced member data
  $group->cache_refresh;

  return [$self->HTTP_OK, { group => $self->_build_enhanced_group($group, $user) }];
}

# Allow a user to leave a usergroup they're a member of
# Unlike removeuser, this doesn't require admin permissions - just membership
sub _leave_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  # Must be logged in
  if ($REQUEST->user->is_guest) {
    return [$self->HTTP_FORBIDDEN, { success => 0, error => 'Must be logged in to leave a group' }];
  }

  # Get the usergroup - force fresh fetch to avoid race condition with recent adds
  my $group_hash = $self->DB->getNodeById($id, 'force');
  unless ($group_hash && $group_hash->{type}{title} eq 'usergroup') {
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'Usergroup not found' }];
  }

  # Check if user is actually in the group using direct DB query for accuracy
  my $user = $REQUEST->user;
  my $user_id = $user->node_id;
  my $in_group = $self->DB->sqlSelect('node_id', 'nodegroup',
    "nodegroup_id=$id AND node_id=$user_id");

  unless ($in_group) {
    return [$self->HTTP_BAD_REQUEST, { success => 0, error => 'You are not a member of this group' }];
  }

  # Get the blessed node object for the leave operation
  my $group = $self->APP->node_by_id($id);
  return $self->$orig($REQUEST, $group, $user);
}

sub leave
{
  my ($self, $REQUEST, $group, $user) = @_;

  # Remove the user from the group
  $self->DB->removeFromNodegroup($group->NODEDATA, $user->NODEDATA, -1);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'You have left ' . $group->title
  }];
}

# Reorder requires array of node_ids in new order
sub _reorder_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_manage_usergroup($REQUEST, $id);
  unless ($output->[0]) {
    return [$output->[1]];
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

  # Refresh and return updated group with enhanced member data
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    group => $self->_build_enhanced_group($group, $user)
  }];
}

# Update description - permission wrapper
sub _description_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $output = $self->_can_manage_usergroup($REQUEST, $id);
  unless ($output->[0]) {
    return [$output->[1], { success => 0, error => 'Permission denied' }];
  }
  my ($node, $user) = ($output->[1], $output->[2]);

  my $data = $REQUEST->JSON_POSTDATA;
  unless (ref $data eq 'HASH' && exists $data->{doctext}) {
    return [$self->HTTP_OK, { success => 0, error => 'Missing doctext parameter' }];
  }

  return $self->$orig($user, $node, $data->{doctext});
}

sub update_description
{
  my ($self, $user, $group, $doctext) = @_;

  # Update the doctext in the document table
  $self->DB->{dbh}->do(
    'UPDATE document SET doctext = ? WHERE document_id = ?',
    {}, $doctext, $group->node_id
  );

  # Refresh the node cache
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    doctext => $doctext
  }];
}

# Transfer ownership - permission wrapper (only owner can transfer)
sub _transfer_ownership_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;

  # Must be logged in
  if ($user->is_guest) {
    return [$self->HTTP_FORBIDDEN, { success => 0, error => 'Must be logged in' }];
  }

  # Get the usergroup
  my $group = $self->APP->node_by_id($id);
  unless ($group && $group->type->title eq 'usergroup') {
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'Usergroup not found' }];
  }

  # Only current owner (or admin) can transfer ownership
  my $owner_id = $self->APP->getParameter($group->NODEDATA, 'usergroup_owner') || 0;
  my $is_owner = ($owner_id && $owner_id == $user->node_id);

  unless ($is_owner || $user->is_admin) {
    return [$self->HTTP_FORBIDDEN, { success => 0, error => 'Only the owner can transfer ownership' }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  unless (ref $data eq 'HASH' && $data->{new_owner_id}) {
    return [$self->HTTP_OK, { success => 0, error => 'Missing new_owner_id parameter' }];
  }

  return $self->$orig($user, $group, $data->{new_owner_id});
}

sub transfer_ownership
{
  my ($self, $user, $group, $new_owner_id) = @_;

  # Verify the new owner is a member of the group
  my %current_members = map { $_ => 1 } @{$group->NODEDATA->{group} || []};
  unless ($current_members{$new_owner_id}) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'New owner must be a member of the group'
    }];
  }

  # Verify new owner is a user (not a usergroup)
  my $new_owner = $self->APP->node_by_id($new_owner_id);
  unless ($new_owner && $new_owner->type->title eq 'user') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'New owner must be a user'
    }];
  }

  # Transfer ownership using setParameter
  # Pass -1 as auth to bypass permission checks (owner is already authorized)
  $self->APP->setParameter($group->NODEDATA, -1, 'usergroup_owner', $new_owner_id);

  # Increment cache version so changes are visible
  $self->DB->{cache}->incrementGlobalVersion($group->NODEDATA);

  # Refresh and return updated group with enhanced member data
  $group->cache_refresh;

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Ownership transferred to ' . $new_owner->title,
    group => $self->_build_enhanced_group($group, $user)
  }];
}

# Weblogify - admin-only permission wrapper
sub _weblogify_permissions
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;

  # Must be admin
  unless ($user->is_admin) {
    return [$self->HTTP_FORBIDDEN, { success => 0, error => 'Only admins can modify weblog settings' }];
  }

  # Get the usergroup
  my $group = $self->APP->node_by_id($id);
  unless ($group && $group->type->title eq 'usergroup') {
    return [$self->HTTP_NOT_FOUND, { success => 0, error => 'Usergroup not found' }];
  }

  # Handle DELETE request - remove weblogify setting
  if ($REQUEST->request_method eq 'DELETE') {
    return $self->remove_weblogify($user, $group);
  }

  # POST request - set/update weblogify
  my $data = $REQUEST->JSON_POSTDATA;
  unless (ref $data eq 'HASH' && defined $data->{ify_display}) {
    return [$self->HTTP_OK, { success => 0, error => 'Missing ify_display parameter' }];
  }

  return $self->$orig($user, $group, $data->{ify_display});
}

sub weblogify
{
  my ($self, $user, $group, $ify_display) = @_;

  my $group_id = $group->node_id;

  # Get the webloggables setting node
  my $wl = $self->DB->getNode('webloggables', 'setting');
  unless ($wl) {
    return [$self->HTTP_OK, { success => 0, error => 'Webloggables setting not found' }];
  }

  # Get current settings and update
  my $wSettings = $self->APP->getVars($wl);
  $wSettings->{$group_id} = $ify_display;
  Everything::setVars($wl, $wSettings);

  # Update each member of the usergroup to add this group to their can_weblog
  my $members = $group->NODEDATA->{group} || [];
  foreach my $member_id (@$members) {
    my $member = $self->DB->getNodeById($member_id);
    next unless $member;

    my $member_vars = $self->APP->getVars($member);
    next unless $member_vars;

    # Skip if already has this group in can_weblog
    my $can_weblog = $member_vars->{can_weblog} || '';
    next if $can_weblog =~ /\b$group_id\b/;

    # Add group to can_weblog
    if (length($can_weblog) == 0) {
      $member_vars->{can_weblog} = $group_id;
    } else {
      $member_vars->{can_weblog} = $can_weblog . ',' . $group_id;
    }

    Everything::setVars($member, $member_vars);
  }

  return [$self->HTTP_OK, {
    success => 1,
    message => "Weblog display set to '$ify_display' for " . $group->title,
    ify_display => $ify_display
  }];
}

sub remove_weblogify
{
  my ($self, $user, $group) = @_;

  my $group_id = $group->node_id;

  # Get the webloggables setting node
  my $wl = $self->DB->getNode('webloggables', 'setting');
  unless ($wl) {
    return [$self->HTTP_OK, { success => 0, error => 'Webloggables setting not found' }];
  }

  # Remove this group from webloggables
  my $wSettings = $self->APP->getVars($wl);
  delete $wSettings->{$group_id};
  Everything::setVars($wl, $wSettings);

  # Remove this group from each member's can_weblog
  my $members = $group->NODEDATA->{group} || [];
  foreach my $member_id (@$members) {
    my $member = $self->DB->getNodeById($member_id);
    next unless $member;

    my $member_vars = $self->APP->getVars($member);
    next unless $member_vars;

    my $can_weblog = $member_vars->{can_weblog} || '';
    next unless $can_weblog;

    # Remove this group_id from the can_weblog list
    my @groups = split(/,/, $can_weblog);
    @groups = grep { $_ != $group_id } @groups;
    $member_vars->{can_weblog} = join(',', @groups);

    Everything::setVars($member, $member_vars);
  }

  return [$self->HTTP_OK, {
    success => 1,
    message => "Weblog ify setting removed from " . $group->title
  }];
}

around ['adduser','removeuser'] => \&_group_operation_permissions;
around ['reorder'] => \&_reorder_permissions;
around ['leave'] => \&_leave_permissions;
around ['update_description'] => \&_description_permissions;
around ['transfer_ownership'] => \&_transfer_ownership_permissions;
around ['weblogify'] => \&_weblogify_permissions;

__PACKAGE__->meta->make_immutable;
1;

