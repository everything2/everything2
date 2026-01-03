package Everything::API::resurrect;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes {
    return {
        'node' => 'resurrect_node',
    };
}

sub resurrect_node {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $APP  = $self->APP;
    my $DB   = $self->DB;

    # Admin-only operation
    unless ($APP->isAdmin($user->NODEDATA)) {
        return [$self->HTTP_OK, {
            success => 0,
            error   => 'Permission denied. This operation requires admin privileges.',
        }];
    }

    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {
            success => 0,
            error   => 'Invalid request data',
        }];
    }

    my $node_id = $data->{node_id};
    my $source  = $data->{source} || 'tomb';  # 'tomb' or 'heaven'

    unless ($node_id && $node_id =~ /^\d+$/) {
        return [$self->HTTP_OK, {
            success => 0,
            error   => 'Invalid node ID',
        }];
    }

    # Check if node already exists
    my $existing = $DB->getNodeById($node_id);
    if ($existing) {
        return [$self->HTTP_OK, {
            success       => 0,
            error         => "That node (id: $node_id) is already alive! No resurrection needed.",
            existingTitle => $existing->{title},
        }];
    }

    # Validate source
    my $burial_ground = ($source eq 'heaven') ? 'heaven' : 'tomb';

    # Attempt resurrection
    my $resurrected_node = $DB->resurrectNode($node_id, $burial_ground);

    unless ($resurrected_node) {
        return [$self->HTTP_OK, {
            success => 0,
            error   => "Resurrection failed! Node $node_id could not be restored from $burial_ground.",
        }];
    }

    # If it's a writeup, try to re-attach to its e2node
    my $e2node_attached = 0;
    if ($resurrected_node->{type_nodetype}) {
        my $type = $DB->getNodeById($resurrected_node->{type_nodetype});
        if ($type && $type->{title} eq 'writeup') {
            # Strip the author suffix from title to find e2node
            my $e2node_title = $resurrected_node->{title};
            $e2node_title =~ s/ \(\w+\)$//;

            my $e2node = $DB->getNode($e2node_title, 'e2node');
            if ($e2node) {
                # Insert into nodegroup
                $DB->insertIntoNodegroup($e2node, $user->NODEDATA, $resurrected_node);
                $DB->updateNode($e2node, -1);
                $e2node_attached = 1;
            }
        }
    }

    # Log the resurrection (linked to Dr. Nate's Secret Lab for security monitor)
    my $lab_node = $DB->getNode("Dr. Nate's Secret Lab", 'restricted_superdoc');
    $APP->securityLog(
        $lab_node->{node_id},
        $user->NODEDATA,
        "$resurrected_node->{title} (id: $resurrected_node->{node_id}) was raised from its $burial_ground"
    );

    # Increment cache version
    $DB->{cache}->incrementGlobalVersion($resurrected_node);

    return [$self->HTTP_OK, {
        success        => 1,
        message        => "Node $node_id successfully resurrected from $burial_ground",
        node_id        => int($resurrected_node->{node_id}),
        title          => $resurrected_node->{title},
        source         => $burial_ground,
        e2nodeAttached => $e2node_attached ? \1 : \0,
    }];
}

around 'resurrect_node' => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;
