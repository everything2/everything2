package Everything::Page::users_with_infravision;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::users_with_infravision - List users who have infravision enabled

=head1 DESCRIPTION

Admin tool showing all users who have the infravision setting enabled.
Infravision allows users to see hidden/special content.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB  = $self->DB;
    my $dbh = $DB->getDatabaseHandle();

    # Query users with infravision=1 in their settings
    my $sql = qq{
        SELECT user.user_id, user.GP, node.title
        FROM setting, user, node
        WHERE setting.setting_id = user.user_id
        AND user.user_id = node.node_id
        AND setting.vars LIKE '%infravision=1%'
        ORDER BY node.title
    };

    my $sth = $dbh->prepare($sql);
    unless ($sth) {
        return {
            type  => 'users_with_infravision',
            error => 'Database prepare error'
        };
    }

    unless ($sth->execute()) {
        return {
            type  => 'users_with_infravision',
            error => 'Database execute error'
        };
    }

    my @users = ();
    while (my $row = $sth->fetchrow_hashref) {
        push @users, {
            user_id => int($row->{user_id}),
            title   => $row->{title},
            gp      => int($row->{GP} || 0)
        };
    }

    # Sort by lowercase title
    @users = sort { lc($a->{title}) cmp lc($b->{title}) } @users;

    return {
        type  => 'users_with_infravision',
        users => \@users,
        count => scalar(@users)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
