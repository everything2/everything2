package Everything::API::e2clients;

use Moose;
extends 'Everything::API';

# API for managing e2clients
# E2clients are API client applications registered by members of the clientdev usergroup
# Provides update endpoint for e2client metadata

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

    # Get the e2client node
    my $node = $DB->getNodeById($id);

    # Check if node exists and is an e2client
    unless ($node && $node->{type}{title} eq 'e2client') {
        return [$self->HTTP_OK, {success => 0, error => 'E2client not found'}];
    }

    # Check edit permissions (clientdev group or admin)
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

    # Update version if provided
    if (exists $data->{version}) {
        my $version = $data->{version} // '';
        if (length($version) > 255) {
            return [$self->HTTP_OK, {success => 0, error => 'Version too long (max 255 characters)'}];
        }
        $node->{version} = $version;
        push @updated_fields, 'version';
    }

    # Update homeurl if provided
    if (exists $data->{homeurl}) {
        my $homeurl = $data->{homeurl} // '';
        if (length($homeurl) > 255) {
            return [$self->HTTP_OK, {success => 0, error => 'Home URL too long (max 255 characters)'}];
        }
        $node->{homeurl} = $homeurl;
        push @updated_fields, 'homeurl';
    }

    # Update dlurl (download URL) if provided
    if (exists $data->{dlurl}) {
        my $dlurl = $data->{dlurl} // '';
        if (length($dlurl) > 255) {
            return [$self->HTTP_OK, {success => 0, error => 'Download URL too long (max 255 characters)'}];
        }
        $node->{dlurl} = $dlurl;
        push @updated_fields, 'dlurl';
    }

    # Update clientstr (client string/user agent) if provided
    if (exists $data->{clientstr}) {
        my $clientstr = $data->{clientstr} // '';
        if (length($clientstr) > 255) {
            return [$self->HTTP_OK, {success => 0, error => 'Client string too long (max 255 characters)'}];
        }
        $node->{clientstr} = $clientstr;
        push @updated_fields, 'clientstr';
    }

    # Update doctext (description) if provided
    if (exists $data->{doctext}) {
        $node->{doctext} = $data->{doctext} // '';
        push @updated_fields, 'doctext';
    }

    unless (@updated_fields) {
        return [$self->HTTP_OK, {success => 0, error => 'No fields to update'}];
    }

    # Update the node in database
    $DB->updateNode($node, $user->node_id);

    return [$self->HTTP_OK, {
        success => 1,
        message => 'E2client updated',
        node_id => int($node->{node_id}),
        updated_fields => \@updated_fields,
    }];
}

around ['update'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
