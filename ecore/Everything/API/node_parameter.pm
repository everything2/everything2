package Everything::API::node_parameter;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use Encode qw(decode_utf8);
use JSON;

=head1 Everything::API::node_parameter

RESTful API for editing node parameters (admin/editor only).

This API enables programmatic access to the node parameter system,
replacing the legacy node_parameter_editor document form submissions.

=head2 Endpoints

GET  /api/node_parameter?node_id=123    - Get parameters for a node
POST /api/node_parameter/set            - Set/update a parameter
POST /api/node_parameter/delete         - Delete a parameter

=cut

sub routes {
    return {
        "/"      => "get",
        "set"    => "set_param",
        "delete" => "delete_param"
    };
}

sub get {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Editors and admins only
    unless ($APP->isEditor($USER->NODEDATA) || $APP->isAdmin($USER->NODEDATA)) {
        return [$self->HTTP_OK, { success => 0, error => 'Access denied. Editors and admins only.' }];
    }

    my $DB    = $self->DB;
    my $query = $REQUEST->cgi;

    my $node_id = $query->param('node_id');

    unless ($node_id) {
        return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
    }

    my $node = $DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, { success => 0, error => "No such node: $node_id" }];
    }

    # Get available parameters for this node's type
    my $available_params = $APP->getParametersForType($node->{type});
    my @params_list;

    if ($available_params) {
        foreach my $param_name (sort keys %$available_params) {
            my $param_info = $available_params->{$param_name};
            push @params_list, {
                name        => $param_name,
                description => $param_info->{description} || '',
                type        => $param_info->{type} || 'string'
            };
        }
    }

    # Get current parameters on this node
    my $current_params = $DB->getNodeParams($node) || {};
    my @current_list;

    foreach my $key (sort keys %$current_params) {
        push @current_list, {
            name  => $key,
            value => $current_params->{$key}
        };
    }

    return [$self->HTTP_OK, {
        success => 1,
        node => {
            node_id => int($node->{node_id}),
            title   => $node->{title},
            type    => $node->{type}{title}
        },
        available_parameters => \@params_list,
        current_parameters   => \@current_list
    }];
}

=head2 set_param

POST /api/node_parameter/set
Body: { node_id: 123, param_name: "foo", param_value: "bar" }

Sets or updates a parameter on the specified node.

=cut

sub set_param {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Editors and admins only
    unless ($APP->isEditor($USER->NODEDATA) || $APP->isAdmin($USER->NODEDATA)) {
        return [$self->HTTP_OK, { success => 0, error => 'Access denied. Editors and admins only.' }];
    }

    my $DB = $self->DB;

    # Parse JSON body - do NOT decode_utf8 before decode_json
    my $postdata = $REQUEST->POSTDATA || '{}';

    my $data;
    my $eval_success = eval { $data = JSON::decode_json($postdata); 1; };
    unless ($eval_success) {
        return [$self->HTTP_OK, { success => 0, error => 'Invalid JSON in request body' }];
    }

    my $node_id     = $data->{node_id};
    my $param_name  = $data->{param_name};
    my $param_value = $data->{param_value};

    unless ($node_id) {
        return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
    }

    unless ($param_name) {
        return [$self->HTTP_OK, { success => 0, error => 'param_name is required' }];
    }

    # Allow empty string but not undef
    unless (defined $param_value) {
        return [$self->HTTP_OK, { success => 0, error => 'param_value is required' }];
    }

    my $node = $DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, { success => 0, error => "No such node: $node_id" }];
    }

    # Validate that this parameter is valid for this node type
    my $available_params = $APP->getParametersForType($node->{type});
    unless ($available_params && exists $available_params->{$param_name}) {
        return [$self->HTTP_OK, {
            success => 0,
            error   => "Parameter '$param_name' is not valid for node type '$node->{type}{title}'"
        }];
    }

    # Set the parameter
    $DB->setNodeParam($node, $param_name, $param_value);

    # Security log
    $APP->securityLog(
        $node,
        $USER->NODEDATA,
        "Set parameter '$param_name' = '$param_value' on node '$node->{title}'"
    );

    return [$self->HTTP_OK, {
        success     => 1,
        action      => 'set',
        node_id     => int($node->{node_id}),
        param_name  => $param_name,
        param_value => $param_value
    }];
}

=head2 delete_param

POST /api/node_parameter/delete
Body: { node_id: 123, param_name: "foo" }

Deletes a parameter from the specified node.

=cut

sub delete_param {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Editors and admins only
    unless ($APP->isEditor($USER->NODEDATA) || $APP->isAdmin($USER->NODEDATA)) {
        return [$self->HTTP_OK, { success => 0, error => 'Access denied. Editors and admins only.' }];
    }

    my $DB = $self->DB;

    # Parse JSON body - do NOT decode_utf8 before decode_json
    my $postdata = $REQUEST->POSTDATA || '{}';

    my $data;
    my $eval_success = eval { $data = JSON::decode_json($postdata); 1; };
    unless ($eval_success) {
        return [$self->HTTP_OK, { success => 0, error => 'Invalid JSON in request body' }];
    }

    my $node_id    = $data->{node_id};
    my $param_name = $data->{param_name};

    unless ($node_id) {
        return [$self->HTTP_OK, { success => 0, error => 'node_id is required' }];
    }

    unless ($param_name) {
        return [$self->HTTP_OK, { success => 0, error => 'param_name is required' }];
    }

    my $node = $DB->getNodeById($node_id);
    unless ($node) {
        return [$self->HTTP_OK, { success => 0, error => "No such node: $node_id" }];
    }

    # Validate that this parameter is valid for this node type
    my $available_params = $APP->getParametersForType($node->{type});
    unless ($available_params && exists $available_params->{$param_name}) {
        return [$self->HTTP_OK, {
            success => 0,
            error   => "Parameter '$param_name' is not valid for node type '$node->{type}{title}'"
        }];
    }

    # Delete the parameter
    $DB->deleteNodeParam($node, $param_name);

    # Security log
    $APP->securityLog(
        $node,
        $USER->NODEDATA,
        "Deleted parameter '$param_name' from node '$node->{title}'"
    );

    return [$self->HTTP_OK, {
        success    => 1,
        action     => 'deleted',
        node_id    => int($node->{node_id}),
        param_name => $param_name
    }];
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::API>

=cut
