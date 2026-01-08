package Everything::API::podcasts;

use Moose;
extends 'Everything::API';

# API for managing podcasts
# Provides update endpoint for podcast metadata

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

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get the podcast node
    my $node = $DB->getNodeById($id);

    # Check if node exists and is a podcast
    unless ($node && $node->{type}{title} eq 'podcast') {
        return [$self->HTTP_OK, {success => 0, error => 'Podcast not found'}];
    }

    # Check edit permissions
    unless ($DB->canUpdateNode($user->NODEDATA, $node)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied'}];
    }

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    my @updated_fields;

    # Update title if provided
    if (exists $data->{title} && defined $data->{title}) {
        my $title = $data->{title};
        $title =~ s/^\s+|\s+$//g;  # Trim whitespace

        if (length($title) == 0) {
            return [$self->HTTP_OK, {success => 0, error => 'Title cannot be empty'}];
        }
        if (length($title) > 240) {
            return [$self->HTTP_OK, {success => 0, error => 'Title too long (max 240 characters)'}];
        }

        $node->{title} = $title;
        push @updated_fields, 'title';
    }

    # Update link if provided
    if (exists $data->{link}) {
        $node->{link} = $data->{link} // '';
        push @updated_fields, 'link';
    }

    # Update description if provided
    if (exists $data->{description}) {
        $node->{description} = $data->{description} // '';
        push @updated_fields, 'description';
    }

    # Update pubdate if provided
    if (exists $data->{pubdate}) {
        $node->{pubdate} = $data->{pubdate} // '';
        push @updated_fields, 'pubdate';
    }

    unless (@updated_fields) {
        return [$self->HTTP_OK, {success => 0, error => 'No fields to update'}];
    }

    # Update the node in database
    $DB->updateNode($node, $user->node_id);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Podcast updated',
        node_id => int($node->{node_id}),
        updated_fields => \@updated_fields,
    }];
}

around ['update'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
