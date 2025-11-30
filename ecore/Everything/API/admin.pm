package Everything::API::admin;

use Moose;
extends 'Everything::API';

# Admin API for system node management
#
# Provides edit capabilities for internal system nodes (maintenance, htmlcode,
# htmlpage, nodelet, nodetype) through a modal interface in Master Control.
#
# This consolidates edit functionality for system nodes, allowing us to
# deprecate the legacy *_edit_page htmlpage delegation functions.

# Whitelist of node types that can be edited through this API
my @EDITABLE_TYPES = qw(
  maintenance
  htmlcode
  htmlpage
  nodelet
  nodetype
  superdoc
  restricted_superdoc
  oppressor_superdoc
  fullpage
);

sub routes
{
  return {
    "node/:id" => "get_node(:id)",
    "node/:id/edit" => "edit_node(:id)",
  }
}

=head1 Everything::API::admin

Admin API for system node management.

=head2 get_node

GET /api/admin/node/:id

Returns node data for editing. Only returns data for whitelisted system node types.

Response:
{
  "node_id": 123,
  "title": "my maintenance node",
  "nodeType": "maintenance",
  "author_user": { "node_id": 113, "title": "root" },
  "maintainedby_user": { "node_id": 113, "title": "root" },
  "createtime": "2025-01-01 00:00:00",
  "editableFields": ["title", "maintainedby_user"]
}

=cut

sub get_node
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use admin API
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can access the admin API'
    }];
  }

  my $node = $APP->node_by_id(int($id));
  unless ($node)
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Node not found',
      message => "No node found with ID $id"
    }];
  }

  my $nodetype = $node->type->title;

  # Check if this node type is editable through admin API
  unless (grep { $_ eq $nodetype } @EDITABLE_TYPES)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Node type not editable',
      message => "Node type '$nodetype' cannot be edited through the admin API"
    }];
  }

  # Get author and maintainer info
  my $author = $node->author_user ? $APP->node_by_id($node->author_user) : undef;
  my $maintainer = $node->NODEDATA->{maintainedby_user}
    ? $APP->node_by_id($node->NODEDATA->{maintainedby_user})
    : undef;

  # Determine editable fields based on node type
  my @editable_fields = ('title', 'maintainedby_user');

  return [$self->HTTP_OK, {
    node_id => $node->node_id,
    title => $node->title,
    nodeType => $nodetype,
    author_user => $author ? {
      node_id => $author->node_id,
      title => $author->title
    } : undef,
    maintainedby_user => $maintainer ? {
      node_id => $maintainer->node_id,
      title => $maintainer->title
    } : undef,
    createtime => $node->NODEDATA->{createtime},
    editableFields => \@editable_fields
  }];
}

=head2 edit_node

POST /api/admin/node/:id/edit

Update a system node's metadata.

Request body:
{
  "title": "new title",
  "maintainedby_user": 113
}

Only fields in editableFields can be updated.

=cut

sub edit_node
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use admin API
  unless ($user->is_admin)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Admin access required',
      message => 'Only administrators can access the admin API'
    }];
  }

  my $node = $APP->node_by_id(int($id));
  unless ($node)
  {
    return [$self->HTTP_NOT_FOUND, {
      error => 'Node not found',
      message => "No node found with ID $id"
    }];
  }

  my $nodetype = $node->type->title;

  # Check if this node type is editable through admin API
  unless (grep { $_ eq $nodetype } @EDITABLE_TYPES)
  {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Node type not editable',
      message => "Node type '$nodetype' cannot be edited through the admin API"
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  unless ($data && ref($data) eq 'HASH')
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Invalid request body',
      message => 'Request body must be a JSON object'
    }];
  }

  # Get the node hashref for direct modification
  my $NODE = $node->NODEDATA;
  my @updated_fields;

  # Update title if provided
  if (exists $data->{title})
  {
    my $new_title = $data->{title};

    # Validate title
    if (!defined($new_title) || length($new_title) == 0)
    {
      return [$self->HTTP_BAD_REQUEST, {
        error => 'Invalid title',
        message => 'Title cannot be empty'
      }];
    }

    if (length($new_title) > 240)
    {
      return [$self->HTTP_BAD_REQUEST, {
        error => 'Invalid title',
        message => 'Title cannot exceed 240 characters'
      }];
    }

    # Check for duplicate title of same type
    if ($new_title ne $node->title)
    {
      my $existing = $APP->node_by_name($new_title, $nodetype);
      if ($existing && $existing->node_id != $node->node_id)
      {
        return [$self->HTTP_CONFLICT, {
          error => 'Duplicate title',
          message => "A $nodetype with title '$new_title' already exists"
        }];
      }
    }

    $NODE->{title} = $new_title;
    push @updated_fields, 'title';
  }

  # Update maintainedby_user if provided
  if (exists $data->{maintainedby_user})
  {
    my $maintainer_id = $data->{maintainedby_user};

    if (defined($maintainer_id))
    {
      # Validate maintainer exists and is a user
      my $maintainer = $APP->node_by_id(int($maintainer_id));
      unless ($maintainer && $maintainer->type->title eq 'user')
      {
        return [$self->HTTP_BAD_REQUEST, {
          error => 'Invalid maintainer',
          message => 'maintainedby_user must be a valid user node ID'
        }];
      }
    }

    $NODE->{maintainedby_user} = $maintainer_id;
    push @updated_fields, 'maintainedby_user';
  }

  # If nothing to update
  unless (@updated_fields)
  {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'No changes',
      message => 'No editable fields provided in request'
    }];
  }

  # Save the node
  $DB->updateNode($NODE, -1);

  # Log the edit
  $APP->securityLog(
    $node->NODEDATA,
    $user->NODEDATA,
    $user->title . " edited $nodetype '" . $node->title . "' via admin API. Fields: " . join(', ', @updated_fields)
  );

  # Return updated node data
  my $maintainer = $NODE->{maintainedby_user}
    ? $APP->node_by_id($NODE->{maintainedby_user})
    : undef;

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Node updated successfully',
    node_id => $node->node_id,
    title => $NODE->{title},
    nodeType => $nodetype,
    maintainedby_user => $maintainer ? {
      node_id => $maintainer->node_id,
      title => $maintainer->title
    } : undef,
    updatedFields => \@updated_fields
  }];
}

__PACKAGE__->meta->make_immutable;
1;
