package Everything::API::nodevars;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use JSON;

# API for CRUD operations on node vars (settings)
# Only accessible to admins
# Works with any node that has vars (setting nodes, user nodes, etc.)

sub routes {
    return {
        '/:id'        => 'get_vars(:id)',     # GET /api/nodevars/123
        '/:id/set'    => 'set_var(:id)',      # POST /api/nodevars/123/set
        '/:id/delete' => 'delete_var(:id)',   # POST /api/nodevars/123/delete
        '/:id/bulk'   => 'bulk_update(:id)',  # POST /api/nodevars/123/bulk
    };
}

# GET /api/nodevars/:node_id - Get all vars for a node
sub get_vars {
    my ($self, $REQUEST, $node_id) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only admins can access this API
    unless ($APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied. Node vars editing is restricted to administrators.'
        }];
    }

    # Validate node_id
    unless ($node_id && $node_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid node_id'
        }];
    }

    # Get the node
    my $node = $self->DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Node not found'
        }];
    }

    # Get vars for this node
    my $vars = Everything::getVars($node) || {};

    # Build sorted list of key-value pairs for display
    my @vars_list;
    foreach my $key (sort keys %$vars) {
        push @vars_list, {
            key => $key,
            value => $vars->{$key}
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        node_id => int($node_id),
        node_title => $node->{title},
        node_type => $node->{type}{title},
        vars => \@vars_list,
        vars_count => scalar(@vars_list)
    }];
}

# POST /api/nodevars/:node_id/set - Set a single var
sub set_var {
    my ($self, $REQUEST, $node_id) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only admins can access this API
    unless ($APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied. Node vars editing is restricted to administrators.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid request data'
        }];
    }

    my $key = $data->{key};
    my $value = $data->{value};

    unless (defined $key && $key ne '') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Key is required'
        }];
    }

    # Validate key format (alphanumeric, underscores, hyphens - can start with number)
    unless ($key =~ /^[a-zA-Z0-9_][a-zA-Z0-9_\-]*$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid key format. Use letters, numbers, underscores, and hyphens.'
        }];
    }

    # Validate node_id
    unless ($node_id && $node_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid node_id'
        }];
    }

    # Get the node
    my $node = $self->DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Node not found'
        }];
    }

    # Get current vars
    my $vars = Everything::getVars($node) || {};

    # Set the value (allow empty string, but undefined deletes)
    if (defined $value) {
        $vars->{$key} = $value;
    } else {
        delete $vars->{$key};
    }

    # Save vars
    Everything::setVars($node, $vars);

    return [$self->HTTP_OK, {
        success => 1,
        key => $key,
        value => $value,
        action => defined $value ? 'set' : 'deleted'
    }];
}

# POST /api/nodevars/:node_id/delete - Delete a single var
sub delete_var {
    my ($self, $REQUEST, $node_id) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only admins can access this API
    unless ($APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied. Node vars editing is restricted to administrators.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid request data'
        }];
    }

    my $key = $data->{key};

    unless (defined $key && $key ne '') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Key is required'
        }];
    }

    # Validate node_id
    unless ($node_id && $node_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid node_id'
        }];
    }

    # Get the node
    my $node = $self->DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Node not found'
        }];
    }

    # Get current vars
    my $vars = Everything::getVars($node) || {};

    # Check if key exists
    unless (exists $vars->{$key}) {
        return [$self->HTTP_OK, {
            success => 0,
            error => "Key '$key' not found"
        }];
    }

    # Delete the key
    delete $vars->{$key};

    # Save vars
    Everything::setVars($node, $vars);

    return [$self->HTTP_OK, {
        success => 1,
        key => $key,
        action => 'deleted'
    }];
}

# POST /api/nodevars/:node_id/bulk - Bulk update/delete vars
sub bulk_update {
    my ($self, $REQUEST, $node_id) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only admins can access this API
    unless ($APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Access denied. Node vars editing is restricted to administrators.'
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid request data'
        }];
    }

    # Validate node_id
    unless ($node_id && $node_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Invalid node_id'
        }];
    }

    # Get the node
    my $node = $self->DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'Node not found'
        }];
    }

    # Get current vars
    my $vars = Everything::getVars($node) || {};

    my @updated;
    my @deleted;
    my @errors;

    # Process updates
    if ($data->{set} && ref($data->{set}) eq 'HASH') {
        foreach my $key (keys %{$data->{set}}) {
            # Validate key format (alphanumeric, underscores, hyphens - can start with number)
            unless ($key =~ /^[a-zA-Z0-9_][a-zA-Z0-9_\-]*$/) {
                push @errors, "Invalid key format: $key";
                next;
            }
            $vars->{$key} = $data->{set}{$key};
            push @updated, $key;
        }
    }

    # Process deletes
    if ($data->{delete} && ref($data->{delete}) eq 'ARRAY') {
        foreach my $key (@{$data->{delete}}) {
            if (exists $vars->{$key}) {
                delete $vars->{$key};
                push @deleted, $key;
            }
        }
    }

    # Save vars
    Everything::setVars($node, $vars);

    return [$self->HTTP_OK, {
        success => 1,
        updated => \@updated,
        deleted => \@deleted,
        errors => \@errors
    }];
}

around ['get_vars', 'set_var', 'delete_var', 'bulk_update'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
