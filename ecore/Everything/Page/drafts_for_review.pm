package Everything::Page::drafts_for_review;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::drafts_for_review - Display drafts awaiting review

=head1 DESCRIPTION

Shows drafts with publication_status set to 'review', sorted by request timestamp.
Editors can see node note counts and latest responses.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns list of drafts awaiting review with optional node note information.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;

    # Guest users cannot see drafts
    if ($user->is_guest) {
        return {
            type => 'drafts_for_review',
            error => 'guest',
            message => 'Only logged-in users can see drafts.'
        };
    }

    my $is_editor = $user->is_editor;

    # Get 'review' publication status
    my $review_status = $DB->getNode('review', 'publication_status');
    return {
        type => 'drafts_for_review',
        error => 'config',
        message => 'Review publication status not found'
    } unless $review_status;

    my $review_id = $review_status->{node_id};

    # Build SQL query - include note information for editors
    my $select_fields = "title, author_user, request.timestamp AS publishtime";
    my $note_join = "";
    my $order_by = "ORDER BY request.timestamp";

    if ($is_editor) {
        # Add latest note and note count for editors
        $select_fields .= ", (Select CONCAT(timestamp, ': ', notetext) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp
    Order By response.timestamp Desc Limit 1) as latestnote,
    (Select count(*) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp) as notecount";

        $order_by = "ORDER BY notecount > 0, request.timestamp";
    }

    my $drafts_cursor = $DB->sqlSelectMany(
        $select_fields,
        "draft
    JOIN node on node_id = draft_id
    JOIN nodenote AS request ON draft_id = nodenote_nodeid
    AND request.noter_user = 0
    LEFT JOIN nodenote AS newer
      ON request.nodenote_nodeid = newer.nodenote_nodeid
      AND newer.noter_user = 0
      AND request.timestamp < newer.timestamp",
        "publication_status = $review_id
    AND newer.timestamp IS NULL",
        $order_by
    );

    # Build draft list
    my @drafts = ();
    while (my $draft_row = $drafts_cursor->fetchrow_hashref) {
        my $author = $DB->getNodeById($draft_row->{author_user});

        my $draft_data = {
            title => $draft_row->{title},
            author => $author ? $author->{title} : 'unknown',
            author_id => $draft_row->{author_user},
            publishtime => $draft_row->{publishtime}
        };

        if ($is_editor) {
            $draft_data->{notecount} = $draft_row->{notecount} || 0;
            $draft_data->{latestnote} = $draft_row->{latestnote} || '';

            # Remove [user] tags from note text
            $draft_data->{latestnote} =~ s/\[user\]//g if $draft_data->{latestnote};
        }

        push @drafts, $draft_data;
    }

    return {
        type => 'drafts_for_review',
        drafts => \@drafts,
        is_editor => $is_editor ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
