package Everything::API::recordings;

use Moose;
extends 'Everything::API';

# API for managing recordings (audio files linked to podcasts)
# Provides create endpoint for new recordings

sub routes {
    return {
        '' => 'create()',
        '/:id' => 'update(:id)',
    };
}

sub create {
    my ($self, $REQUEST) = @_;

    # Must be logged in
    if ($REQUEST->is_guest) {
        return [$self->HTTP_UNAUTHORIZED, {success => 0, error => 'Must be logged in'}];
    }

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get POST data
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {success => 0, error => 'Invalid request data'}];
    }

    # Validate title
    my $title = $data->{title};
    unless ($title && length($title) > 0) {
        return [$self->HTTP_OK, {success => 0, error => 'Title is required'}];
    }

    $title =~ s/^\s+|\s+$//g;  # Trim whitespace

    if (length($title) > 64) {
        return [$self->HTTP_OK, {success => 0, error => 'Title too long (max 64 characters)'}];
    }

    # Validate appears_in (the podcast this recording belongs to)
    my $appears_in = $data->{appears_in};
    unless ($appears_in && $appears_in =~ /^\d+$/) {
        return [$self->HTTP_OK, {success => 0, error => 'appears_in podcast ID is required'}];
    }

    # Verify the podcast exists and user can edit it
    my $podcast = $DB->getNodeById($appears_in);
    unless ($podcast && $podcast->{type}{title} eq 'podcast') {
        return [$self->HTTP_OK, {success => 0, error => 'Podcast not found'}];
    }

    unless ($DB->canUpdateNode($user->NODEDATA, $podcast)) {
        return [$self->HTTP_OK, {success => 0, error => 'Permission denied - cannot edit this podcast'}];
    }

    # Get the recording nodetype
    my $recording_type = $DB->getType('recording');
    unless ($recording_type) {
        return [$self->HTTP_OK, {success => 0, error => 'Recording nodetype not found'}];
    }

    # Check if a recording with this title already exists
    my $existing = $DB->getNode($title, 'recording');
    if ($existing) {
        return [$self->HTTP_OK, {success => 0, error => 'A recording with this title already exists'}];
    }

    # Create the recording node
    my $node_id = $DB->insertNode($title, $recording_type->{node_id}, $user->node_id);
    unless ($node_id) {
        return [$self->HTTP_OK, {success => 0, error => 'Failed to create recording node'}];
    }

    # Update the recording-specific fields
    $DB->sqlUpdate('recording', {
        appears_in => $appears_in,
        recording_of => 0,
        link => '',
        read_by => 0
    }, "recording_id=$node_id");

    return [$self->HTTP_OK, {
        success => 1,
        message => 'Recording created',
        node_id => int($node_id),
        title => $title,
        appears_in => int($appears_in),
    }];
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

    # Get the recording node
    my $node = $DB->getNodeById($id);

    # Check if node exists and is a recording
    unless ($node && $node->{type}{title} eq 'recording') {
        return [$self->HTTP_OK, {success => 0, error => 'Recording not found'}];
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
    my $result = { success => 1 };

    # Update title if provided
    if (exists $data->{title} && defined $data->{title}) {
        my $title = $data->{title};
        $title =~ s/^\s+|\s+$//g;  # Trim whitespace

        if (length($title) == 0) {
            return [$self->HTTP_OK, {success => 0, error => 'Title cannot be empty'}];
        }
        if (length($title) > 64) {
            return [$self->HTTP_OK, {success => 0, error => 'Title too long (max 64 characters)'}];
        }

        $node->{title} = $title;
        push @updated_fields, 'title';
    }

    # Update link if provided
    if (exists $data->{link}) {
        $node->{link} = $data->{link} // '';
        push @updated_fields, 'link';
    }

    # Update read_by if provided (by username)
    if (exists $data->{read_by_name} && defined $data->{read_by_name}) {
        my $reader_name = $data->{read_by_name};
        $reader_name =~ s/^\s+|\s+$//g;

        if (length($reader_name) > 0) {
            my $reader = $DB->getNode($reader_name, 'user');
            if ($reader) {
                $node->{read_by} = $reader->{node_id};
                $result->{read_by} = {
                    node_id => int($reader->{node_id}),
                    title => $reader->{title}
                };
                push @updated_fields, 'read_by';
            } else {
                return [$self->HTTP_OK, {success => 0, error => "Reader '$reader_name' not found"}];
            }
        } else {
            $node->{read_by} = 0;
            $result->{read_by} = undef;
            push @updated_fields, 'read_by';
        }
    }

    # Update recording_of if author and title provided
    if (exists $data->{writeup_author} && exists $data->{writeup_title}) {
        my $author_name = $data->{writeup_author};
        my $writeup_title = $data->{writeup_title};

        $author_name =~ s/^\s+|\s+$//g if $author_name;
        $writeup_title =~ s/^\s+|\s+$//g if $writeup_title;

        if ($author_name && $writeup_title) {
            # Find the author
            my $author = $DB->getNode($author_name, 'user');
            unless ($author) {
                return [$self->HTTP_OK, {success => 0, error => "Writeup author '$author_name' not found"}];
            }

            # Find the e2node
            my $e2node = $DB->getNode($writeup_title, 'e2node');
            unless ($e2node) {
                return [$self->HTTP_OK, {success => 0, error => "E2node '$writeup_title' not found"}];
            }

            # Find the writeup by this author under that e2node
            my $writeup_id = $DB->sqlSelect(
                'node.node_id',
                'node LEFT JOIN writeup ON node.node_id = writeup.writeup_id',
                "writeup.parent_e2node = " . $e2node->{node_id} .
                " AND node.author_user = " . $author->{node_id}
            );

            if ($writeup_id) {
                $node->{recording_of} = $writeup_id;
                my $writeup = $DB->getNodeById($writeup_id);
                $result->{recording_of} = {
                    node_id => int($writeup_id),
                    title => $writeup ? $writeup->{title} : '',
                    author => {
                        node_id => int($author->{node_id}),
                        title => $author->{title}
                    }
                };
                push @updated_fields, 'recording_of';
            } else {
                return [$self->HTTP_OK, {success => 0, error => "No writeup by '$author_name' found under '$writeup_title'"}];
            }
        } elsif (!$author_name && !$writeup_title) {
            # Clear the recording_of
            $node->{recording_of} = 0;
            $result->{recording_of} = undef;
            push @updated_fields, 'recording_of';
        }
        # If only one is provided, ignore (partial info)
    }

    unless (@updated_fields) {
        return [$self->HTTP_OK, {success => 0, error => 'No fields to update'}];
    }

    # Update the node in database
    $DB->updateNode($node, $user->node_id);

    $result->{message} = 'Recording updated';
    $result->{node_id} = int($node->{node_id});
    $result->{updated_fields} = \@updated_fields;

    return [$self->HTTP_OK, $result];
}

around ['create', 'update'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
