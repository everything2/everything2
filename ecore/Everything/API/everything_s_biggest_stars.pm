package Everything::API::everything_s_biggest_stars;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_s_biggest_stars - top users by star count

=head1 DESCRIPTION

Public leaderboard of the top 100 users by C<stars>. Moved out of
C<Everything::Page::everything_s_biggest_stars>'s buildReactData (#4546): the Page is a pure gate.

  GET /api/everything_s_biggest_stars

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $limit = 100;

    my $dbh = $self->DB->getDatabaseHandle();
    my $sth = $dbh->prepare(qq{
        SELECT u.user_id, n.title, u.stars
        FROM user u
        JOIN node n ON u.user_id = n.node_id
        WHERE u.stars > 0
        ORDER BY u.stars DESC
        LIMIT $limit
    });
    $sth->execute();

    my @users;
    while (my $row = $sth->fetchrow_hashref()) {
        push @users, {
            node_id => int($row->{user_id}),
            title   => $row->{title},
            stars   => int($row->{stars} || 0),
        };
    }
    $sth->finish();

    return [$self->HTTP_OK, { success => 1, users => \@users, limit => $limit }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
