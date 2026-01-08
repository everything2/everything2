package Everything::Controller::recording;

use Moose;
extends 'Everything::Controller';

# Controller for recording nodes
# Migrated from Everything::Delegation::htmlpage::recording_display_page, recording_edit_page

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    my $node_data = $node->NODEDATA;
    my $is_guest = $user->is_guest ? 1 : 0;
    my $is_admin = $user->is_admin ? 1 : 0;

    # Check if user can edit this recording
    my $can_edit = $DB->canUpdateNode($user->NODEDATA, $node->NODEDATA) ? 1 : 0;

    # Get the writeup this is a recording of
    my $recording_of_data = undef;
    if ($node_data->{recording_of} && $node_data->{recording_of} > 0) {
        my $writeup = $APP->node_by_id($node_data->{recording_of});
        if ($writeup) {
            my $writeup_author = $APP->node_by_id($writeup->NODEDATA->{author_user});
            $recording_of_data = {
                node_id => int($writeup->node_id),
                title => $writeup->title,
                author => $writeup_author ? {
                    node_id => int($writeup_author->node_id),
                    title => $writeup_author->title
                } : undef,
            };
        }
    }

    # Get the reader
    my $read_by_data = undef;
    if ($node_data->{read_by} && $node_data->{read_by} > 0) {
        my $reader = $APP->node_by_id($node_data->{read_by});
        if ($reader) {
            $read_by_data = {
                node_id => int($reader->node_id),
                title => $reader->title
            };
        }
    }

    # Get the podcast this appears in
    my $appears_in_data = undef;
    if ($node_data->{appears_in} && $node_data->{appears_in} > 0) {
        my $podcast = $APP->node_by_id($node_data->{appears_in});
        if ($podcast) {
            $appears_in_data = {
                node_id => int($podcast->node_id),
                title => $podcast->title
            };
        }
    }

    # Build recording data
    my $recording_data = {
        node_id => int($node->node_id),
        title => $node->title,
        link => $node_data->{link} || '',
        recording_of => $recording_of_data,
        read_by => $read_by_data,
        appears_in => $appears_in_data,
    };

    # Build contentData for React
    my $content_data = {
        type => 'recording',
        recording => $recording_data,
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

    # Get the writeup this is a recording of
    my $recording_of_data = undef;
    if ($node_data->{recording_of} && $node_data->{recording_of} > 0) {
        my $writeup = $APP->node_by_id($node_data->{recording_of});
        if ($writeup) {
            my $writeup_author = $APP->node_by_id($writeup->NODEDATA->{author_user});
            $recording_of_data = {
                node_id => int($writeup->node_id),
                title => $writeup->title,
                author => $writeup_author ? {
                    node_id => int($writeup_author->node_id),
                    title => $writeup_author->title
                } : undef,
            };
        }
    }

    # Get the reader
    my $read_by_data = undef;
    if ($node_data->{read_by} && $node_data->{read_by} > 0) {
        my $reader = $APP->node_by_id($node_data->{read_by});
        if ($reader) {
            $read_by_data = {
                node_id => int($reader->node_id),
                title => $reader->title
            };
        }
    }

    # Get the podcast this appears in
    my $appears_in_data = undef;
    if ($node_data->{appears_in} && $node_data->{appears_in} > 0) {
        my $podcast = $APP->node_by_id($node_data->{appears_in});
        if ($podcast) {
            $appears_in_data = {
                node_id => int($podcast->node_id),
                title => $podcast->title
            };
        }
    }

    # Build recording data for editing
    my $recording_data = {
        node_id => int($node->node_id),
        title => $node->title,
        link => $node_data->{link} || '',
        recording_of => $recording_of_data,
        read_by => $read_by_data,
        appears_in => $appears_in_data,
    };

    # Build contentData for React
    my $content_data = {
        type => 'recording_edit',
        recording => $recording_data,
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
