package Everything::Page::reputation_graph;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::reputation_graph - Monthly reputation graph for writeups (vertical layout)

=head1 DESCRIPTION

Shows a table-style reputation graph with upvotes, downvotes, and cumulative reputation
per month. Users can view graphs for writeups they've voted on, their own writeups,
or admins can view any writeup.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with writeup info and permission checks.
Vote data is fetched client-side via the reputation API.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    my $writeup_id = $REQUEST->param('id');

    # Validate writeup_id
    unless ($writeup_id && $writeup_id =~ /^\d+$/) {
        return {
            type => 'reputation_graph',
            layout => 'vertical',
            error => 'Not a valid node. Try clicking the "Rep Graph" link from a writeup you have already voted on.'
        };
    }

    my $writeup = $DB->getNodeById($writeup_id);

    unless ($writeup) {
        return {
            type => 'reputation_graph',
            layout => 'vertical',
            error => 'Not a valid node. Try clicking the "Rep Graph" link from a writeup you have already voted on.'
        };
    }

    # Check if it's a writeup (type 117)
    unless ($writeup->{type_nodetype} == 117) {
        return {
            type => 'reputation_graph',
            layout => 'vertical',
            error => 'You can only view the reputation graph for writeups. Try clicking on the "Rep Graph" link from a writeup you have already voted on.'
        };
    }

    my $is_admin = $USER->is_admin;
    my $can_view = $is_admin;

    # Users can view graphs of their own writeups
    if (!$can_view) {
        $can_view = ($writeup->{author_user} == $USER->{node_id});
    }

    # Check if user has voted on this writeup
    if (!$can_view) {
        my $sth = $DB->{dbh}->prepare(
            'SELECT weight FROM vote WHERE vote_id = ? AND voter_user = ?'
        );
        $sth->execute($writeup_id, $USER->{node_id});
        $can_view = 1 if $sth->rows > 0;
    }

    # Get author info
    my $author = $DB->getNodeById($writeup->{author_user});

    return {
        type => 'reputation_graph',
        layout => 'vertical',
        writeup => {
            node_id => $writeup->{node_id},
            title => $writeup->{title},
            publishtime => $writeup->{publishtime}
        },
        author => {
            node_id => $author ? $author->{node_id} : 0,
            title => $author ? $author->{title} : 'unknown'
        },
        can_view => $can_view ? 1 : 0,
        is_admin => $is_admin ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::reputation>

=cut
