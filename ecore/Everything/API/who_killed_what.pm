package Everything::API::who_killed_what;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::who_killed_what - admin view of a user's writeup kill history

=head1 DESCRIPTION

Admin tool: list the writeups a given user (default: the acting admin) has killed, paginated, with
links back to Node Heaven Visitation. Moved out of C<Everything::Page::who_killed_what>'s
buildReactData (#4530): the Page is a pure gate, React reads heavenuser/offset/limit off the URL and
calls this.

  GET /api/who_killed_what?heavenuser=<name>&offset=<n>&limit=<n>

Admin-only. Ships data + an error C<state> ('admin' / 'user_not_found'); the copy + the
offset/limit dropdown options live in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    my $offset     = int($REQUEST->param('offset') || 0);
    my $limit      = int($REQUEST->param('limit')  || 100);
    my $heavenuser = $REQUEST->param('heavenuser');
    $heavenuser = defined($heavenuser) ? $heavenuser : '';
    $offset = 0   if $offset < 0;
    $limit  = 100 if $limit < 1;
    $limit  = 500 if $limit > 500;

    # Default target is the acting admin; heavenuser overrides.
    my $target_user  = $USER->NODEDATA;
    my $target_title = $USER->title;
    if ($heavenuser ne '') {
        my $found = $DB->getNode($heavenuser, 'user');
        return [$self->HTTP_OK, { success => 0, state => 'user_not_found', heavenuser => $heavenuser }]
            unless $found;
        $target_user  = $found;
        $target_title = $found->{title};
    }

    my $user_id = int($DB->getId($target_user));
    my $writeup_type_id = int(($DB->getType('writeup') || {})->{node_id} || 0);

    my $total_kills = $DB->sqlSelect(
        'count(*)', 'heaven',
        "type_nodetype = $writeup_type_id AND killa_user = $user_id"
    );

    my $csr = $DB->sqlSelectMany(
        '*', 'heaven',
        "type_nodetype = $writeup_type_id AND killa_user = $user_id",
        "ORDER BY title LIMIT $offset, $limit"
    );

    my $node_heaven = $DB->getNode('Node Heaven Visitation', 'superdoc');
    my $node_heaven_id = $node_heaven ? int($node_heaven->{node_id}) : 0;

    my @kills;
    while (my $row = $csr->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user}, 'light');
        push @kills, {
            node_id    => int($row->{node_id}),
            title      => $row->{title},
            author_id  => $author ? int($author->{node_id}) : 0,
            author     => $author ? $author->{title} : 'Unknown',
            reputation => int($row->{reputation} || 0),
            createtime => $row->{createtime},
        };
    }

    return [$self->HTTP_OK, {
        success        => 1,
        target_user    => $target_title,
        # 0 + $user_id: interpolated into SQL above (sets the string flag), so re-numify
        # or JSON ships the node_id as a string (#4152).
        target_user_id => 0 + $user_id,
        total_kills    => int($total_kills || 0),
        kills          => \@kills,
        offset         => $offset,
        limit          => $limit,
        node_heaven_id => $node_heaven_id,
        heavenuser     => $heavenuser,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
