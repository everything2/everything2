package Everything::API::documents;

use Moose;
extends 'Everything::API';

sub routes {
    return {
        '/:id' => 'update(:id)',
    };
}

# Check if a node's type is 'document' or extends 'document'
# Walks up the nodetype inheritance chain
sub _is_document_type {
    my ($self, $node) = @_;

    my $type = $node->{type};
    return 0 unless $type;

    # Walk up the inheritance chain
    while ($type) {
        return 1 if $type->{title} eq 'document';

        # Move up to parent type
        last unless $type->{extends_nodetype};
        $type = $self->DB->getType($type->{extends_nodetype});
    }

    return 0;
}

# Check if a node's type is an "oppressor" type (admin-only)
# These types can only be edited by editors/admins, not by authors
sub _is_oppressor_type {
    my ($self, $node) = @_;

    my $type_title = $node->{type}{title} // '';
    return $type_title =~ /^oppressor_/;
}

sub update {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    # Get the document node
    my $node = $self->DB->getNodeById($id);

    # Check if node exists and is a document type (or extends document)
    unless ($node && $self->_is_document_type($node)) {
        return [$self->HTTP_OK, {success => 0, error => 'Document not found'}];
    }

    # Check edit permissions
    # - Editors can edit any document type
    # - Authors can edit their own documents EXCEPT oppressor types
    # - Oppressor types (oppressor_document, etc.) require editor privileges
    my $user = $REQUEST->user;
    my $can_edit = 0;
    my $is_oppressor = $self->_is_oppressor_type($node);

    if ($self->APP->isEditor($user->NODEDATA)) {
        $can_edit = 1;
    } elsif (!$is_oppressor && $node->{author_user} == $user->node_id) {
        # Non-oppressor documents can be edited by their author
        $can_edit = 1;
    }

    unless ($can_edit) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && defined $data->{doctext}) {
        return [$self->HTTP_OK, {success => 0, error => 'Missing doctext'}];
    }

    # Update the document
    $node->{doctext} = $data->{doctext};

    # Update the node in database
    $self->DB->updateNode($node, $user->node_id);

    return [$self->HTTP_OK, {
        success => 1,
        document => {
            node_id => $node->{node_id},
            title => $node->{title},
            doctext => $node->{doctext},
        }
    }];
}

__PACKAGE__->meta->make_immutable;

1;
