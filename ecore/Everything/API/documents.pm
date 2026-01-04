package Everything::API::documents;

use Moose;
extends 'Everything::API';

sub routes {
    return {
        '/:id' => 'update(:id)',
    };
}

sub update {
    my ($self, $REQUEST, $id) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    # Get the document node
    my $node = $self->DB->getNodeById($id);

    unless ($node && $node->{type}{title} eq 'document') {
        return [$self->HTTP_OK, {success => 0, error => 'Document not found'}];
    }

    # Check edit permissions - editors or author
    my $user = $REQUEST->user;
    my $can_edit = 0;

    if ($self->APP->isEditor($user->NODEDATA)) {
        $can_edit = 1;
    } elsif ($node->{author_user} == $user->node_id) {
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
