package Everything::Page::who_killed_what;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::who_killed_what - Admin tool to view user kill history

=head1 DESCRIPTION

Shows which writeups a user (or the current admin) has killed.
Results link to Node Heaven Visitation for examination.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Admin only
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'who_killed_what',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my $offset = int($query->param('offset') || 0);
    my $limit  = int($query->param('limit') || 100);
    my $heavenuser = $query->param('heavenuser') || '';

    # Determine which user to query
    my $target_user = $USER->NODEDATA;
    my $target_title = $USER->title;

    if ($heavenuser) {
        my $found = $DB->getNode($heavenuser, 'user');
        if ($found) {
            $target_user = $found;
            $target_title = $found->{title};
        } else {
            return {
                type  => 'who_killed_what',
                error => "User not found: $heavenuser"
            };
        }
    }

    my $user_id = $DB->getId($target_user);
    my $writeup_type = $DB->getType('writeup');
    my $writeup_type_id = $writeup_type->{node_id};

    # Get total kill count
    my $total_kills = $DB->sqlSelect(
        'count(*)', 'heaven',
        "type_nodetype = $writeup_type_id AND killa_user = $user_id"
    );

    # Get paginated results
    my $csr = $DB->sqlSelectMany(
        '*', 'heaven',
        "type_nodetype = $writeup_type_id AND killa_user = $user_id",
        "ORDER BY title LIMIT $offset, $limit"
    );

    my @kills = ();
    my $node_heaven = $DB->getNode('Node Heaven Visitation', 'superdoc');
    my $node_heaven_id = $node_heaven ? $node_heaven->{node_id} : 0;

    while (my $row = $csr->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user}, 'light');
        push @kills, {
            node_id    => int($row->{node_id}),
            title      => $row->{title},
            author_id  => $author ? int($author->{node_id}) : 0,
            author     => $author ? $author->{title} : 'Unknown',
            reputation => int($row->{reputation} || 0),
            createtime => $row->{createtime}
        };
    }

    # Generate offset options for form
    my @offset_options = map { $_ * 200 } (0..25);
    my @limit_options = map { $_ * 50 } (1..10);

    return {
        type              => 'who_killed_what',
        target_user       => $target_title,
        target_user_id    => int($user_id),
        total_kills       => int($total_kills || 0),
        kills             => \@kills,
        offset            => $offset,
        limit             => $limit,
        offset_options    => \@offset_options,
        limit_options     => \@limit_options,
        node_heaven_id    => $node_heaven_id,
        heavenuser        => $heavenuser
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
