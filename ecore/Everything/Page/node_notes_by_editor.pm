package Everything::Page::node_notes_by_editor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::node_notes_by_editor - View node notes by a specific editor

=head1 DESCRIPTION

Admin tool to view all node notes created by a specific editor/user.
Supports pagination through results.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'node_notes_by_editor',
            error => 'This page is restricted to administrators.'
        };
    }

    my $result = {
        type    => 'node_notes_by_editor',
        node_id => $REQUEST->node->node_id
    };

    my $target_username = $q->param('targetUser') || '';
    $result->{target_username} = $target_username;

    # No search yet
    return $result unless $target_username && $q->param('gotime');

    # Look up the target user
    my $target_user = $DB->getNode($target_username, 'user');

    unless ($target_user) {
        $result->{error} = "Could not find user '$target_username'";
        return $result;
    }

    my $uid = $target_user->{node_id};
    $result->{target_user_id} = int($uid);

    # Pagination
    my $start = int($q->param('start') || 0);
    my $limit = int($q->param('limit') || 50);
    $limit = 100 if $limit > 100;  # Cap at 100

    my $where = "noter_user=$uid";
    my $count = $DB->sqlSelect('count(*)', 'nodenote', $where);

    $result->{total_count} = int($count);
    $result->{start}       = $start;
    $result->{limit}       = $limit;

    # Get writeup and draft type IDs for author display
    my $writeup_type = $DB->getType('writeup');
    my $draft_type   = $DB->getType('draft');
    my $writeup_id   = $writeup_type ? $writeup_type->{node_id} : 0;
    my $draft_id     = $draft_type ? $draft_type->{node_id} : 0;

    # Fetch notes
    my $csr = $DB->sqlSelectMany(
        'node_id, type_nodetype, author_user, notetext, timestamp',
        'nodenote JOIN node ON node.node_id=nodenote.nodenote_nodeid',
        $where,
        "ORDER BY timestamp DESC LIMIT $start,$limit"
    );

    my @notes = ();
    while (my $ref = $csr->fetchrow_hashref()) {
        next unless $ref->{node_id};

        my $note_text = $ref->{notetext};
        $note_text =~ s/</&lt;/g;

        my $entry = {
            node_id    => int($ref->{node_id}),
            note       => $note_text,
            timestamp  => $ref->{timestamp}
        };

        # Get node title
        my $node = $DB->getNodeById($ref->{node_id}, 'light');
        $entry->{node_title} = $node ? $node->{title} : 'Unknown';

        # Show author for writeups and drafts
        if ($ref->{type_nodetype} == $writeup_id || $ref->{type_nodetype} == $draft_id) {
            if ($ref->{author_user}) {
                my $author = $DB->getNodeById($ref->{author_user}, 'light');
                $entry->{author_id}    = int($ref->{author_user});
                $entry->{author_title} = $author ? $author->{title} : 'Unknown';
            }
        }

        push @notes, $entry;
    }
    $csr->finish();

    $result->{notes} = \@notes;

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
