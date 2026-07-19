package Everything::API::user_statistics;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::user_statistics - user login-activity counts over time windows

=head1 DESCRIPTION

Admin-only activity statistics (total users + how many logged in over the last day/week/2wk/4wk).
The source node is a restricted superdoc; that gate lives here now -- a pure gate serves the page to
anyone and /api/pagestate bypasses node permissions, so the API is the real boundary (#4546). Moved
out of C<Everything::Page::user_statistics>'s buildReactData.

  GET /api/user_statistics

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    return [$self->HTTP_OK, { success => 0, state => 'permission' }]
        unless $APP->isAdmin($user->NODEDATA);

    my $dbh = $self->DB->getDatabaseHandle();

    my ($total_users)          = $dbh->selectrow_array("SELECT COUNT(user_id) FROM user");
    my ($users_ever_logged_in) = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE lasttime NOT LIKE '0%'");
    my ($users_last_24h)       = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24)");
    my ($users_last_week)      = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7)");
    my ($users_last_2weeks)    = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7*2)");
    my ($users_last_4weeks)    = $dbh->selectrow_array(
        "SELECT COUNT(user_id) FROM user WHERE UNIX_TIMESTAMP(lasttime) > (UNIX_TIMESTAMP(NOW()) - 3600*24*7*4)");

    return [$self->HTTP_OK, {
        success              => 1,
        total_users          => int($total_users || 0),
        users_ever_logged_in => int($users_ever_logged_in || 0),
        users_last_24h       => int($users_last_24h || 0),
        users_last_week      => int($users_last_week || 0),
        users_last_2weeks    => int($users_last_2weeks || 0),
        users_last_4weeks    => int($users_last_4weeks || 0),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
