package Everything::Controller::podcast;

use Moose;
extends 'Everything::Controller';

# Controller for podcast nodes
# Migrated from Everything::Delegation::htmlpage::podcast_display_page, podcast_edit_page

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    my $node_data = $node->NODEDATA;
    my $is_guest = $user->is_guest ? 1 : 0;
    my $is_admin = $user->is_admin ? 1 : 0;

    # Check if user can edit this podcast
    my $can_edit = $DB->canUpdateNode($user->NODEDATA, $node->NODEDATA) ? 1 : 0;

    # Get author info
    my $author = $APP->node_by_id($node_data->{createdby_user});
    my $author_data = $author ? {
        node_id => int($author->node_id),
        title => $author->title
    } : { node_id => 0, title => 'Unknown' };

    # Get recordings for this podcast
    # Note: recording table only has: recording_id, recording_of, appears_in, link, read_by
    my @recordings;
    my $recording_type = $DB->getType('recording');
    if ($recording_type) {
        my $csr = $DB->sqlSelectMany(
            'r.recording_id, n.title, r.link, r.read_by, r.recording_of',
            'recording r JOIN node n ON r.recording_id = n.node_id',
            'r.appears_in = ' . $node->node_id,
            'ORDER BY n.createtime DESC'
        );

        if ($csr) {
            while (my $row = $csr->fetchrow_hashref()) {
                my $reader = $row->{read_by} ? $APP->node_by_id($row->{read_by}) : undef;
                my $writeup = $row->{recording_of} ? $APP->node_by_id($row->{recording_of}) : undef;

                push @recordings, {
                    node_id => int($row->{recording_id}),
                    title => $row->{title},
                    link => $row->{link} || '',
                    read_by => $reader ? {
                        node_id => int($reader->node_id),
                        title => $reader->title
                    } : undef,
                    recording_of => $writeup ? {
                        node_id => int($writeup->node_id),
                        title => $writeup->title
                    } : undef,
                };
            }
            $csr->finish();
        }
    }

    # Build podcast data
    my $podcast_data = {
        node_id => int($node->node_id),
        title => $node->title,
        description => $node_data->{description} || '',
        link => $node_data->{link} || '',
        pubdate => $node_data->{pubdate} || '',
        author => $author_data,
    };

    # Build contentData for React
    my $content_data = {
        type => 'podcast',
        podcast => $podcast_data,
        recordings => \@recordings,
        can_edit => $can_edit,
        is_guest => $is_guest,
        is_admin => $is_admin,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node_data,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

sub edit {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Check edit permission
    unless ($DB->canUpdateNode($user->NODEDATA, $node->NODEDATA)) {
        # Redirect to display if can't edit
        return $self->display($REQUEST, $node);
    }

    my $node_data = $node->NODEDATA;

    # Get author info
    my $author = $APP->node_by_id($node_data->{createdby_user});
    my $author_data = $author ? {
        node_id => int($author->node_id),
        title => $author->title
    } : { node_id => 0, title => 'Unknown' };

    # Get recordings for this podcast
    my @recordings;
    my $recording_type = $DB->getType('recording');
    if ($recording_type) {
        my $csr = $DB->sqlSelectMany(
            'r.recording_id, n.title, r.link, r.read_by, r.recording_of',
            'recording r JOIN node n ON r.recording_id = n.node_id',
            'r.appears_in = ' . $node->node_id,
            'ORDER BY n.createtime DESC'
        );

        if ($csr) {
            while (my $row = $csr->fetchrow_hashref()) {
                my $reader = $row->{read_by} ? $APP->node_by_id($row->{read_by}) : undef;
                my $writeup = $row->{recording_of} ? $APP->node_by_id($row->{recording_of}) : undef;

                push @recordings, {
                    node_id => int($row->{recording_id}),
                    title => $row->{title},
                    link => $row->{link} || '',
                    read_by => $reader ? {
                        node_id => int($reader->node_id),
                        title => $reader->title
                    } : undef,
                    recording_of => $writeup ? {
                        node_id => int($writeup->node_id),
                        title => $writeup->title
                    } : undef,
                };
            }
            $csr->finish();
        }
    }

    # Build podcast data for editing
    my $podcast_data = {
        node_id => int($node->node_id),
        title => $node->title,
        description => $node_data->{description} || '',
        link => $node_data->{link} || '',
        pubdate => $node_data->{pubdate} || '',
        author => $author_data,
    };

    # Build contentData for React
    my $content_data = {
        type => 'podcast_edit',
        podcast => $podcast_data,
        recordings => \@recordings,
        is_admin => $user->is_admin ? 1 : 0,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node_data,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our edit data
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
