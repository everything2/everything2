package Everything::API::category;

use Moose;
use JSON;
use Encode qw(decode_utf8);
extends 'Everything::API';

# API endpoint for category operations
# Route: /api/category/*

sub routes {
  return {
    'update'          => 'update_category',
    'update_meta'     => 'update_category_meta',
    'reorder_members' => 'reorder_members',
    'remove_member'   => 'remove_member',
    'add_member'      => 'add_member',
    'lookup_owner'    => 'lookup_owner',
    'list'            => 'list_categories',
    'node_categories' => 'node_categories'
  };
}

# POST /api/category/update
# Updates a category's description
sub update_category {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  # Must be logged in
  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in to edit categories' }];
  }

  # Parse request body
  my $postdata = $REQUEST->POSTDATA;
  $postdata = decode_utf8($postdata) if $postdata;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  unless ($json_ok && $data) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
  }

  my $node_id = $data->{node_id};
  my $doctext = $data->{doctext};

  unless ($node_id) {
    return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
  }

  # Get the category node
  my $category = $APP->node_by_id($node_id);
  unless ($category) {
    return [$self->HTTP_OK, { success => 0, error => 'Category not found' }];
  }

  # Verify it's actually a category
  my $node_type = $category->NODEDATA->{type}{title} || '';
  unless ($node_type eq 'category') {
    return [$self->HTTP_OK, { success => 0, error => 'Node is not a category' }];
  }

  # Check permissions
  my $guest_user_id = $self->CONF->guest_user;
  my $is_public = $category->NODEDATA->{author_user} == $guest_user_id;
  my $can_edit = 0;

  if ($user->is_admin) {
    $can_edit = 1;
  }
  elsif ($category->NODEDATA->{author_user} == $user->node_id) {
    # User owns this category
    $can_edit = 1;
  }
  elsif ($is_public) {
    # Public category - any logged-in user can edit
    $can_edit = 1;
  }
  else {
    # Check if user is in the usergroup that maintains this category
    foreach my $ug (@{ $user->usergroup_memberships || [] }) {
      if ($ug->node_id == $category->NODEDATA->{author_user}) {
        $can_edit = 1;
        last;
      }
    }
  }

  unless ($can_edit) {
    return [$self->HTTP_OK, { success => 0, error => 'You do not have permission to edit this category' }];
  }

  # Update the category description
  # doctext can be empty/undefined - that's valid
  $doctext //= '';

  # Update the document table
  my $result = $DB->sqlUpdate(
    'document',
    { doctext => $doctext },
    "document_id = $node_id"
  );

  if ($result) {
    return [$self->HTTP_OK, { success => 1, message => 'Category updated successfully' }];
  }
  else {
    return [$self->HTTP_OK, { success => 0, error => 'Failed to update category' }];
  }
}

# POST /api/category/update_meta
# Updates category title and/or owner (editors+ only)
sub update_category_meta {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  # Must be logged in as editor+
  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }
  unless ($user->is_editor) {
    return [$self->HTTP_OK, { success => 0, error => 'Only editors can change category settings' }];
  }

  # Parse request body
  my $postdata = $REQUEST->POSTDATA;
  $postdata = decode_utf8($postdata) if $postdata;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  unless ($json_ok && $data) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
  }

  my $node_id = $data->{node_id};
  unless ($node_id) {
    return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
  }

  # Get the category node
  my $category = $APP->node_by_id($node_id);
  unless ($category) {
    return [$self->HTTP_OK, { success => 0, error => 'Category not found' }];
  }

  # Verify it's actually a category
  my $node_type = $category->NODEDATA->{type}{title} || '';
  unless ($node_type eq 'category') {
    return [$self->HTTP_OK, { success => 0, error => 'Node is not a category' }];
  }

  my %updates;

  # Handle title change
  if (defined $data->{title} && $data->{title} ne $category->title) {
    my $new_title = $APP->cleanNodeName($data->{title});

    unless ($new_title && length($new_title) > 0) {
      return [$self->HTTP_OK, { success => 0, error => 'Title cannot be empty' }];
    }

    # Check for duplicate category names
    my $existing = $DB->getNode($new_title, 'category');
    if ($existing && $existing->{node_id} != $node_id) {
      return [$self->HTTP_OK, { success => 0, error => "A category named '$new_title' already exists" }];
    }

    $updates{title} = $new_title;
  }

  # Handle owner change
  if (defined $data->{author_user}) {
    my $new_author_id = $data->{author_user};

    # Validate the new owner exists (user or usergroup)
    my $new_owner = $APP->node_by_id($new_author_id);
    unless ($new_owner) {
      return [$self->HTTP_OK, { success => 0, error => 'Invalid owner' }];
    }

    my $owner_type = $new_owner->NODEDATA->{type}{title} || '';
    my $guest_user_id = $self->CONF->guest_user;

    # Must be user, usergroup, or guest user
    unless ($owner_type eq 'user' || $owner_type eq 'usergroup' || $new_author_id == $guest_user_id) {
      return [$self->HTTP_OK, { success => 0, error => 'Owner must be a user or usergroup' }];
    }

    $updates{author_user} = $new_author_id;
  }

  unless (%updates) {
    return [$self->HTTP_OK, { success => 1, message => 'No changes to save' }];
  }

  # Update the node table
  my $result = $DB->sqlUpdate(
    'node',
    \%updates,
    "node_id = $node_id"
  );

  if ($result) {
    return [$self->HTTP_OK, { success => 1, message => 'Category settings updated' }];
  }
  else {
    return [$self->HTTP_OK, { success => 0, error => 'Failed to update category settings' }];
  }
}

# POST /api/category/reorder_members
# Reorders category members (owner or editors)
sub reorder_members {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }

  # Parse request body
  my $postdata = $REQUEST->POSTDATA;
  $postdata = decode_utf8($postdata) if $postdata;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  unless ($json_ok && $data) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
  }

  my $node_id = $data->{node_id};
  my $member_ids = $data->{member_ids};

  unless ($node_id) {
    return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
  }
  unless ($member_ids && ref($member_ids) eq 'ARRAY') {
    return [$self->HTTP_OK, { success => 0, error => 'member_ids array is required' }];
  }

  # Get the category node
  my $category = $APP->node_by_id($node_id);
  unless ($category) {
    return [$self->HTTP_OK, { success => 0, error => 'Category not found' }];
  }

  # Verify it's actually a category
  my $node_type = $category->NODEDATA->{type}{title} || '';
  unless ($node_type eq 'category') {
    return [$self->HTTP_OK, { success => 0, error => 'Node is not a category' }];
  }

  # Check permissions - editors can manage any category, owners can manage non-public
  my $guest_user_id = $self->CONF->guest_user;
  my $is_public = $category->NODEDATA->{author_user} == $guest_user_id;
  my $can_manage = 0;

  if ($user->is_editor) {
    $can_manage = 1;
  }
  elsif (!$is_public && $category->NODEDATA->{author_user} == $user->node_id) {
    $can_manage = 1;
  }
  elsif (!$is_public) {
    # Check usergroup membership
    foreach my $ug (@{ $user->usergroup_memberships || [] }) {
      if ($ug->node_id == $category->NODEDATA->{author_user}) {
        $can_manage = 1;
        last;
      }
    }
  }

  unless ($can_manage) {
    return [$self->HTTP_OK, { success => 0, error => 'You cannot manage members of this category' }];
  }

  # Get the category linktype
  my $category_linktype = $DB->getNode('category', 'linktype');
  my $linktype_id = $category_linktype->{node_id};

  # Update food values for each member in order
  my $food = 10;
  foreach my $member_id (@$member_ids) {
    $DB->sqlUpdate(
      'links',
      { food => $food },
      "from_node = $node_id AND to_node = $member_id AND linktype = $linktype_id"
    );
    $food += 10;
  }

  return [$self->HTTP_OK, { success => 1, message => 'Member order updated' }];
}

# POST /api/category/remove_member
# Removes a node from a category (owner or editors)
sub remove_member {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }

  # Parse request body
  my $postdata = $REQUEST->POSTDATA;
  $postdata = decode_utf8($postdata) if $postdata;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  unless ($json_ok && $data) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
  }

  my $node_id = $data->{node_id};
  my $member_id = $data->{member_id};

  unless ($node_id && $member_id) {
    return [$self->HTTP_OK, { success => 0, error => 'node_id and member_id are required' }];
  }

  # Get the category node
  my $category = $APP->node_by_id($node_id);
  unless ($category) {
    return [$self->HTTP_OK, { success => 0, error => 'Category not found' }];
  }

  # Verify it's actually a category
  my $node_type = $category->NODEDATA->{type}{title} || '';
  unless ($node_type eq 'category') {
    return [$self->HTTP_OK, { success => 0, error => 'Node is not a category' }];
  }

  # Check permissions - editors can manage any category, owners can manage non-public
  my $guest_user_id = $self->CONF->guest_user;
  my $is_public = $category->NODEDATA->{author_user} == $guest_user_id;
  my $can_manage = 0;

  if ($user->is_editor) {
    $can_manage = 1;
  }
  elsif (!$is_public && $category->NODEDATA->{author_user} == $user->node_id) {
    $can_manage = 1;
  }
  elsif (!$is_public) {
    # Check usergroup membership
    foreach my $ug (@{ $user->usergroup_memberships || [] }) {
      if ($ug->node_id == $category->NODEDATA->{author_user}) {
        $can_manage = 1;
        last;
      }
    }
  }

  unless ($can_manage) {
    return [$self->HTTP_OK, { success => 0, error => 'You cannot manage members of this category' }];
  }

  # Get the category linktype
  my $category_linktype = $DB->getNode('category', 'linktype');
  my $linktype_id = $category_linktype->{node_id};

  # Delete the link
  my $result = $DB->sqlDelete(
    'links',
    "from_node = $node_id AND to_node = $member_id AND linktype = $linktype_id"
  );

  if ($result) {
    return [$self->HTTP_OK, { success => 1, message => 'Member removed from category' }];
  }
  else {
    return [$self->HTTP_OK, { success => 0, error => 'Member not found in category' }];
  }
}

# GET /api/category/lookup_owner?name=X
# Looks up a user or usergroup by name (editors+ only)
sub lookup_owner {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $DB   = $self->DB;

  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }
  unless ($user->is_editor) {
    return [$self->HTTP_OK, { success => 0, error => 'Only editors can lookup owners' }];
  }

  my $name = $REQUEST->cgi->param('name');
  unless ($name && length($name) > 0) {
    return [$self->HTTP_OK, { success => 0, error => 'name parameter is required' }];
  }

  # Try to find as user first
  my $found_node = $DB->getNode($name, 'user');

  # If not found as user, try usergroup
  unless ($found_node) {
    $found_node = $DB->getNode($name, 'usergroup');
  }

  if ($found_node) {
    return [$self->HTTP_OK, {
      success => 1,
      found => 1,
      node_id => $found_node->{node_id},
      title => $found_node->{title},
      type => $found_node->{type}{title} || ''
    }];
  }
  else {
    return [$self->HTTP_OK, { success => 1, found => 0 }];
  }
}

# GET /api/category/list?node_id=X
# Returns categories the user can add a node to
# Separated into "your_categories" and "public_categories"
sub list_categories {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $DB   = $self->DB;

  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }

  my $target_node_id = $REQUEST->cgi->param('node_id');

  my $guest_user_id = $self->CONF->guest_user;
  my $uid = $user->node_id;

  # Get all usergroups the user is in
  my $sql = "SELECT DISTINCT ug.node_id
    FROM node ug, nodegroup ng
    WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$uid";

  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute();

  my @user_group_ids = ($uid);
  while (my $n = $ds->fetchrow_hashref) {
    push @user_group_ids, $n->{node_id};
  }
  my $userGroupClause = join(',', @user_group_ids);

  # Get the category nodetype ID
  my $category_type = $DB->getNode('category', 'nodetype');
  my $category_type_id = $category_type->{node_id};

  # Get the category linktype for checking existing membership
  my $category_linktype = $DB->getNode('category', 'linktype');
  my $linktype_id = $category_linktype->{node_id};

  # Build exclusion clause if we have a target node
  my $exclude_clause = '';
  if ($target_node_id) {
    # Exclude categories that already contain this node
    $exclude_clause = "AND n.node_id NOT IN (
      SELECT from_node FROM links
      WHERE to_node = $target_node_id AND linktype = $linktype_id
    )";
  }

  # Get user's own categories and usergroup categories
  $sql = "SELECT n.node_id, n.title, n.author_user, u.title AS author_username
    FROM node n
    LEFT JOIN node u ON n.author_user = u.node_id
    WHERE n.author_user IN ($userGroupClause)
    AND n.type_nodetype = $category_type_id
    $exclude_clause
    ORDER BY n.title";

  $ds = $DB->{dbh}->prepare($sql);
  $ds->execute();

  my @your_categories = ();
  while (my $n = $ds->fetchrow_hashref) {
    push @your_categories, {
      node_id => $n->{node_id},
      title => $n->{title},
      author_user => $n->{author_user},
      author_username => $n->{author_username}
    };
  }

  # Get public categories (owned by Guest User)
  $sql = "SELECT n.node_id, n.title, n.author_user, u.title AS author_username
    FROM node n
    LEFT JOIN node u ON n.author_user = u.node_id
    WHERE n.author_user = $guest_user_id
    AND n.type_nodetype = $category_type_id
    $exclude_clause
    ORDER BY n.title";

  $ds = $DB->{dbh}->prepare($sql);
  $ds->execute();

  my @public_categories = ();
  while (my $n = $ds->fetchrow_hashref) {
    push @public_categories, {
      node_id => $n->{node_id},
      title => $n->{title},
      author_user => $n->{author_user},
      author_username => $n->{author_username}
    };
  }

  # For editors, also get all other categories (not owned by user or public)
  my @other_categories = ();
  if ($user->is_editor) {
    $sql = "SELECT n.node_id, n.title, n.author_user, u.title AS author_username
      FROM node n
      LEFT JOIN node u ON n.author_user = u.node_id
      WHERE n.author_user NOT IN ($userGroupClause)
      AND n.author_user != $guest_user_id
      AND n.type_nodetype = $category_type_id
      $exclude_clause
      ORDER BY n.title";

    $ds = $DB->{dbh}->prepare($sql);
    $ds->execute();

    while (my $n = $ds->fetchrow_hashref) {
      push @other_categories, {
        node_id => $n->{node_id},
        title => $n->{title},
        author_user => $n->{author_user},
        author_username => $n->{author_username}
      };
    }
  }

  return [$self->HTTP_OK, {
    success => 1,
    your_categories => \@your_categories,
    public_categories => \@public_categories,
    other_categories => \@other_categories,
    is_editor => $user->is_editor ? 1 : 0
  }];
}

# POST /api/category/add_member
# Adds a node to a category
sub add_member {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP  = $self->APP;
  my $DB   = $self->DB;

  if ($user->is_guest) {
    return [$self->HTTP_OK, { success => 0, error => 'Must be logged in' }];
  }

  # Parse request body
  my $postdata = $REQUEST->POSTDATA;
  $postdata = decode_utf8($postdata) if $postdata;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  unless ($json_ok && $data) {
    return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
  }

  my $category_id = $data->{category_id};
  my $node_id = $data->{node_id};

  unless ($category_id && $node_id) {
    return [$self->HTTP_OK, { success => 0, error => 'category_id and node_id are required' }];
  }

  # Get the category node
  my $category = $APP->node_by_id($category_id);
  unless ($category) {
    return [$self->HTTP_OK, { success => 0, error => 'Category not found' }];
  }

  # Verify it's actually a category
  my $node_type = $category->NODEDATA->{type}{title} || '';
  unless ($node_type eq 'category') {
    return [$self->HTTP_OK, { success => 0, error => 'Node is not a category' }];
  }

  # Check if user can add to this category
  my $guest_user_id = $self->CONF->guest_user;
  my $is_public = $category->NODEDATA->{author_user} == $guest_user_id;
  my $can_add = 0;

  if ($user->is_editor) {
    $can_add = 1;
  }
  elsif ($is_public) {
    # Public category - any logged-in user can add
    $can_add = 1;
  }
  elsif ($category->NODEDATA->{author_user} == $user->node_id) {
    # User owns this category
    $can_add = 1;
  }
  else {
    # Check usergroup membership
    foreach my $ug (@{ $user->usergroup_memberships || [] }) {
      if ($ug->node_id == $category->NODEDATA->{author_user}) {
        $can_add = 1;
        last;
      }
    }
  }

  unless ($can_add) {
    return [$self->HTTP_OK, { success => 0, error => 'You cannot add to this category' }];
  }

  # Get the target node
  my $target_node = $APP->node_by_id($node_id);
  unless ($target_node) {
    return [$self->HTTP_OK, { success => 0, error => 'Target node not found' }];
  }

  # Get the category linktype
  my $category_linktype = $DB->getNode('category', 'linktype');
  my $linktype_id = $category_linktype->{node_id};

  # Check if already in category
  my $existing = $DB->sqlSelect(
    'from_node',
    'links',
    "from_node = $category_id AND to_node = $node_id AND linktype = $linktype_id"
  );

  if ($existing) {
    return [$self->HTTP_OK, { success => 0, error => 'Node is already in this category' }];
  }

  # Get the highest food value currently in the category (for ordering)
  my $max_food = $DB->sqlSelect(
    'MAX(food)',
    'links',
    "from_node = $category_id AND linktype = $linktype_id"
  ) || 0;

  # Insert the link
  my $result = $DB->sqlInsert(
    'links',
    {
      from_node => $category_id,
      to_node => $node_id,
      linktype => $linktype_id,
      food => $max_food + 10
    }
  );

  if ($result) {
    return [$self->HTTP_OK, {
      success => 1,
      message => 'Node added to category',
      category_title => $category->title
    }];
  }
  else {
    return [$self->HTTP_OK, { success => 0, error => 'Failed to add node to category' }];
  }
}

# GET /api/category/node_categories?node_id=X
# Returns categories that contain this node, with permission info for removal
sub node_categories {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $DB   = $self->DB;

  # Guest users can see categories but not remove
  my $is_guest = $user->is_guest;
  my $uid = $is_guest ? 0 : $user->node_id;

  my $node_id = $REQUEST->cgi->param('node_id');
  unless ($node_id) {
    return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
  }

  my $guest_user_id = $self->CONF->guest_user;

  # Get usergroups the user is in (for permission checking)
  my @user_group_ids = ($uid);
  unless ($is_guest) {
    my $sql = "SELECT DISTINCT ug.node_id
      FROM node ug, nodegroup ng
      WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$uid";

    my $ds = $DB->{dbh}->prepare($sql);
    $ds->execute();

    while (my $n = $ds->fetchrow_hashref) {
      push @user_group_ids, $n->{node_id};
    }
  }

  # Get the category linktype
  my $category_linktype = $DB->getNode('category', 'linktype');
  my $linktype_id = $category_linktype->{node_id};

  # Get all categories containing this node
  my $sql = "SELECT c.node_id, c.title, c.author_user, u.title AS author_username
    FROM links l
    JOIN node c ON l.from_node = c.node_id
    LEFT JOIN node u ON c.author_user = u.node_id
    WHERE l.to_node = $node_id AND l.linktype = $linktype_id
    ORDER BY c.title";

  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute();

  my @categories = ();
  while (my $row = $ds->fetchrow_hashref) {
    my $is_public = $row->{author_user} == $guest_user_id;

    # Determine if user can remove from this category
    my $can_remove = 0;
    unless ($is_guest) {
      if ($user->is_editor) {
        $can_remove = 1;
      }
      elsif (!$is_public) {
        # Check if user owns or is in the owning usergroup
        foreach my $gid (@user_group_ids) {
          if ($gid == $row->{author_user}) {
            $can_remove = 1;
            last;
          }
        }
      }
      # Public categories: no one can remove (anyone can add, but removal is restricted)
    }

    push @categories, {
      node_id => $row->{node_id},
      title => $row->{title},
      author_user => $row->{author_user},
      author_username => $row->{author_username},
      is_public => $is_public ? 1 : 0,
      can_remove => $can_remove
    };
  }

  return [$self->HTTP_OK, {
    success => 1,
    categories => \@categories
  }];
}

__PACKAGE__->meta->make_immutable;
1;
