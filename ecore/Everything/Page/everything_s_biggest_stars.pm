package Everything::Page::everything_s_biggest_stars;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_s_biggest_stars - Everything's Biggest Stars List

=head1 DESCRIPTION

Displays the top 100 users by star count.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with list of users sorted by stars.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $limit = 100;

    # Query users with most stars
    my $sql = qq{
        SELECT
            u.user_id,
            n.title,
            u.stars
        FROM user u
        JOIN node n ON u.user_id = n.node_id
        WHERE u.stars > 0
        ORDER BY u.stars DESC
        LIMIT $limit
    };

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    my @users;
    while (my $row = $sth->fetchrow_hashref()) {
        push @users, {
            node_id => $row->{user_id},
            title => $row->{title},
            stars => $row->{stars}
        };
    }

    $sth->finish();

    return {
        type => 'everything_s_biggest_stars',
        users => \@users,
        limit => $limit
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
