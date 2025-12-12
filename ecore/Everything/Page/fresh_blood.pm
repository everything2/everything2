package Everything::Page::fresh_blood;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::fresh_blood - Display newly registered users

=head1 DESCRIPTION

Shows users who enrolled in the past week, with login status and node notes.
Paginated display of 50 users per page.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $query = $REQUEST->cgi;

    my $usertype = $DB->getType('user');
    return { type => 'fresh_blood', error => 'Could not find user type' }
        unless $usertype;

    my $usertype_id = $usertype->{node_id};

    # Get total count of new users this week
    my $sql = "SELECT COUNT(*) FROM node WHERE type_nodetype = ? AND createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK)";
    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($usertype_id);
    my ($total_users) = $sth->fetchrow();

    # Get count of users who have logged in
    $sql = "SELECT COUNT(*) FROM user, node WHERE user_id = node_id AND createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK) AND lasttime > 0";
    $sth = $DB->{dbh}->prepare($sql);
    $sth->execute();
    my ($logged_in_count) = $sth->fetchrow();

    if (!$total_users || $total_users == 0) {
        return {
            type => 'fresh_blood',
            total_users => 0,
            logged_in_count => 0,
            users => [],
            message => 'No new users this week'
        };
    }

    # Pagination
    my $page_size = 50;
    my $start = int($query->param('start') || 0);
    $start = 0 if $start < 0;

    # Main query
    $sql = qq|
        SELECT user_id, nick, title, createtime, lasttime,
            (SELECT notetext FROM nodenote WHERE nodenote_nodeid = user_id LIMIT 1) AS notetext
        FROM node
        JOIN user ON node_id = user_id
        WHERE createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK)
        ORDER BY createtime DESC
        LIMIT ?, ?
    |;

    $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($start, $page_size);

    my @users;
    while (my $row = $sth->fetchrow_hashref) {
        push @users, {
            user_id    => int($row->{user_id}),
            title      => $row->{title},
            nick       => $row->{nick},
            createtime => $row->{createtime},
            lasttime   => $row->{lasttime} || 0,
            notetext   => $row->{notetext} || ''
        };
    }

    return {
        type            => 'fresh_blood',
        total_users     => int($total_users),
        logged_in_count => int($logged_in_count),
        users           => \@users,
        start           => $start,
        page_size       => $page_size
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
