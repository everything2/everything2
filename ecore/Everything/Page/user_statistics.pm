package Everything::Page::user_statistics;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::user_statistics - User activity statistics

=head1 DESCRIPTION

Shows statistics about user login activity over various time periods.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB  = $self->DB;
    my $dbh = $DB->getDatabaseHandle();

    # Total users
    my ($total_users) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user"
    );

    # Users who have ever logged in
    my ($users_ever_logged_in) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE lasttime NOT LIKE '0%'"
    );

    # Users in last 24 hours
    my ($users_last_24h) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24)"
    );

    # Users in last week
    my ($users_last_week) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7)"
    );

    # Users in last 2 weeks
    my ($users_last_2weeks) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7*2)"
    );

    # Users in last 4 weeks
    my ($users_last_4weeks) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7*4)"
    );

    return {
        type                 => 'user_statistics',
        total_users          => int($total_users || 0),
        users_ever_logged_in => int($users_ever_logged_in || 0),
        users_last_24h       => int($users_last_24h || 0),
        users_last_week      => int($users_last_week || 0),
        users_last_2weeks    => int($users_last_2weeks || 0),
        users_last_4weeks    => int($users_last_4weeks || 0)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
