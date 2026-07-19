package Everything::API::everything_s_best_writeups;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_s_best_writeups - the 50 most-cooled writeups (editor-only)

=head1 DESCRIPTION

The top 50 writeups by C<cooled>. Editor-only: the old Page carried the C<StaffOnly> role, so the
gate now lives here -- the API is the real boundary (a pure gate serves the page to anyone, and
/api/pagestate bypasses controller gates). Non-editors get C<state: 'permission'>. Moved out of
C<Everything::Page::everything_s_best_writeups>'s buildReactData (#4546).

  GET /api/everything_s_best_writeups

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    return [$self->HTTP_OK, { success => 0, state => 'permission' }]
        unless $APP->isEditor($user->NODEDATA);

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare(q{
        SELECT writeup_id, cooled
        FROM writeup
        ORDER BY cooled DESC
        LIMIT 50
    });
    $sth->execute();

    my @writeups;
    while (my $row = $sth->fetchrow_hashref()) {
        my $writeup = $DB->getNodeById($row->{writeup_id});
        next unless $writeup;
        my $parent = $DB->getNodeById($writeup->{parent_e2node});
        my $author = $DB->getNodeById($writeup->{author_user});
        push @writeups, {
            writeup_id    => int($writeup->{node_id}),
            writeup_title => $writeup->{title},
            parent_id     => $parent ? int($parent->{node_id}) : 0,
            parent_title  => $parent ? $parent->{title} : '',
            author_id     => $author ? int($author->{node_id}) : 0,
            author_title  => $author ? $author->{title} : '',
            cooled        => int($row->{cooled} || 0),
        };
    }
    $sth->finish();

    return [$self->HTTP_OK, { success => 1, writeups => \@writeups }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
