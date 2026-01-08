package Everything::Controller::e2poll;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# E2Poll Controller
#
# Handles display of e2poll nodes (user polls).
# Polls can be voted on directly from their page using the poll API.
#
# Features:
# - Display poll question and options
# - Show results after voting or when closed
# - Voting via /api/poll/vote endpoint
# - Admin vote deletion via /api/poll/delete_vote
# - BasicEdit for raw editing (gods only)

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $node_data = $node->NODEDATA;

    # Get poll options from doctext (newline separated)
    my @options = split /\s*\n\s*/, ($node_data->{doctext} || '');

    # Get poll results
    my @results = split /,/, ($node_data->{e2poll_results} || '');

    # Ensure results array matches options length
    while (scalar(@results) < scalar(@options)) {
        push @results, 0;
    }

    # Check if current user has voted
    my $user_vote = undef;
    if (!$user->is_guest) {
        my $vote = $DB->sqlSelect(
            'choice',
            'pollvote',
            "voter_user=" . $user->node_id . " AND pollvote_id=" . $node->node_id
        );
        $user_vote = defined($vote) ? int($vote) : undef;
    }

    # Get author info
    my $author_node = $node_data->{poll_author}
        ? $self->APP->node_by_id($node_data->{poll_author})
        : undef;

    my $poll_author = $author_node ? {
        node_id => int($author_node->node_id),
        title   => $author_node->title
    } : { node_id => 0, title => 'Unknown' };

    # Can the user edit this poll?
    my $can_edit = 0;
    if (!$user->is_guest) {
        $can_edit = ($node_data->{poll_status} eq 'new' &&
            ($node_data->{poll_author} == $user->node_id || $user->is_admin)) ? 1 : 0;
    }

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin  ? 1 : 0
    };

    # Build contentData for React
    my $content_data = {
        type => 'e2poll',
        poll => {
            poll_id       => int($node->node_id),
            title         => $node->title,
            question      => $node_data->{question} || $node->title,
            options       => \@options,
            results       => \@results,
            totalvotes    => int($node_data->{totalvotes} || 0),
            poll_status   => $node_data->{poll_status} || 'new',
            poll_author   => $poll_author,
            user_vote     => $user_vote,
            can_edit      => $can_edit,
            multiple      => $node_data->{multiple} ? 1 : 0,
            createtime    => $node_data->{createtime},
            type_nodetype => $node_data->{type_nodetype}
        },
        user => $user_data
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node_data,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2      => $e2,
        REQUEST => $REQUEST,
        node    => $node
    );
    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
