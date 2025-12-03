package Everything::API::nodelets;

use Moose;
use namespace::autoclean;
use JSON;
use Encode qw(decode_utf8);
extends 'Everything::API';

=head1 NAME

Everything::API::nodelets - Nodelet management API

=head1 DESCRIPTION

Handles getting and updating user nodelet order and visibility preferences.

=head1 ENDPOINTS

=head2 GET /api/nodelets

Get user's current nodelet configuration.

Response (JSON):
{
  "success": true,
  "nodelets": [
    {
      "node_id": 123,
      "title": "Messages"
    },
    ...
  ]
}

=head2 POST /api/nodelets

Update user's nodelet order.

Request body (JSON):
{
  "nodelet_ids": [123, 456, 789]
}

Response (JSON):
{
  "success": true
}

=cut

sub routes {
    return {
        '/' => 'get_or_update'
    };
}

sub get_or_update {
    my ($self, $REQUEST) = @_;

    my $method = lc($REQUEST->request_method());

    if ($method eq 'get') {
        return $self->get_nodelets($REQUEST);
    } elsif ($method eq 'post') {
        return $self->update_nodelets($REQUEST);
    }

    return [$self->HTTP_METHOD_NOT_ALLOWED, {
        success => 0,
        error => 'method_not_allowed',
        message => 'Use GET or POST for this endpoint'
    }];
}

sub get_nodelets {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $VARS = $REQUEST->VARS;
    my $DB = $self->DB;

    # Get nodelet order from VARS (comma-separated node IDs)
    my $nodelet_order = $VARS->{nodelets} || '';
    my @nodelet_ids = split(/,/, $nodelet_order);

    my @nodelets;
    foreach my $node_id (@nodelet_ids) {
        $node_id =~ s/^\s+|\s+$//g;  # trim whitespace
        next unless $node_id =~ /^\d+$/;  # skip non-numeric

        my $nodelet = $DB->getNodeById($node_id);
        if ($nodelet) {
            push @nodelets, {
                node_id => int($nodelet->{node_id}),
                title => $nodelet->{title}
            };
        }
    }

    return [$self->HTTP_OK, {
        success => 1,
        nodelets => \@nodelets
    }];
}

sub update_nodelets {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Parse JSON body
    my $postdata = $REQUEST->POSTDATA();
    $postdata = decode_utf8($postdata) if $postdata;

    my $data;
    my $json_ok = eval {
        $data = JSON::decode_json($postdata);
        1;
    };
    if (!$json_ok || !$data) {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_json',
            message => 'Invalid JSON in request body'
        }];
    }

    my $nodelet_ids = $data->{nodelet_ids};
    unless ($nodelet_ids && ref($nodelet_ids) eq 'ARRAY') {
        return [$self->HTTP_BAD_REQUEST, {
            success => 0,
            error => 'invalid_nodelet_ids',
            message => 'nodelet_ids must be an array'
        }];
    }

    # Validate all IDs are numeric and nodelets exist
    my @validated_ids;
    foreach my $id (@$nodelet_ids) {
        unless ($id =~ /^\d+$/) {
            return [$self->HTTP_BAD_REQUEST, {
                success => 0,
                error => 'invalid_nodelet_id',
                message => "Invalid nodelet ID: $id"
            }];
        }

        my $nodelet = $DB->getNodeById($id);
        unless ($nodelet) {
            return [$self->HTTP_NOT_FOUND, {
                success => 0,
                error => 'nodelet_not_found',
                message => "Nodelet not found: $id"
            }];
        }

        push @validated_ids, $id;
    }

    # Store as comma-separated string in VARS
    my $nodelet_order = join(',', @validated_ids);

    # Update user VARS
    my $user_node = $user->NODEDATA;
    Everything::setVars($user_node, { nodelets => $nodelet_order });

    # Update the node in the database
    my $update_ok = eval {
        $DB->updateNode($user_node, -1);
        1;
    };

    unless ($update_ok) {
        return [$self->HTTP_INTERNAL_SERVER_ERROR, {
            success => 0,
            error => 'update_failed',
            message => 'Failed to update nodelet order'
        }];
    }

    return [$self->HTTP_OK, {
        success => 1
    }];
}

around ['get_or_update'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;
