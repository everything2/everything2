package Everything::API::node_notes_by_editor;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::node_notes_by_editor - all node notes written by a specific editor

=head1 DESCRIPTION

Admin tool to view every node note created by a given user, paginated. Moved out of
C<Everything::Page::node_notes_by_editor>'s buildReactData (#4528): the Page is a pure gate, React
reads targetUser/gotime/start/limit off the URL and calls this.

  GET /api/node_notes_by_editor?targetUser=<name>&gotime=1&start=<n>&limit=<n>

Admin-only. Ships data + an error C<state> ('admin' / 'user_not_found'); the copy lives in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    my $target_username = $REQUEST->param('targetUser') || '';

    # No search yet: return the empty shell (React shows the search form).
    return [$self->HTTP_OK, { success => 1, target_username => $target_username, notes => [] }]
        unless $target_username && $REQUEST->param('gotime');

    my $target_user = $DB->getNode($target_username, 'user');
    return [$self->HTTP_OK, { success => 0, state => 'user_not_found', target_username => $target_username }]
        unless $target_user;

    my $uid = int($target_user->{node_id});

    my $start = int($REQUEST->param('start') || 0);
    my $limit = int($REQUEST->param('limit') || 50);
    $limit = 100 if $limit > 100;
    $limit = 50  if $limit < 1;
    $start = 0   if $start < 0;

    my $where = "noter_user=$uid";   # $uid is an int -> injection-safe
    my $count = $DB->sqlSelect('count(*)', 'nodenote', $where) || 0;

    my $writeup_id = ($DB->getType('writeup') || {})->{node_id} || 0;
    my $draft_id   = ($DB->getType('draft')   || {})->{node_id} || 0;

    my $csr = $DB->sqlSelectMany(
        'node_id, type_nodetype, author_user, notetext, timestamp',
        'nodenote JOIN node ON node.node_id=nodenote.nodenote_nodeid',
        $where, "ORDER BY timestamp DESC LIMIT $start,$limit"
    );

    my @notes;
    while (my $ref = $csr->fetchrow_hashref()) {
        next unless $ref->{node_id};
        (my $note_text = $ref->{notetext}) =~ s/</&lt;/g;

        my $node = $DB->getNodeById($ref->{node_id}, 'light');
        my $entry = {
            node_id    => int($ref->{node_id}),
            note       => $note_text,
            timestamp  => $ref->{timestamp},
            node_title => $node ? $node->{title} : 'Unknown',
        };

        if (($ref->{type_nodetype} == $writeup_id || $ref->{type_nodetype} == $draft_id) && $ref->{author_user}) {
            my $author = $DB->getNodeById($ref->{author_user}, 'light');
            $entry->{author_id}    = int($ref->{author_user});
            $entry->{author_title} = $author ? $author->{title} : 'Unknown';
        }

        push @notes, $entry;
    }
    $csr->finish();

    return [$self->HTTP_OK, {
        success         => 1,
        target_username => $target_user->{title},
        target_user_id  => $uid,
        total_count     => int($count),
        start           => $start,
        limit           => $limit,
        notes           => \@notes,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
