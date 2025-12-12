package Everything::Page::freshly_bloodied;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::freshly_bloodied - Display locked new users

=head1 DESCRIPTION

Shows users who enrolled in the past week and have been locked,
with information about who locked them and why.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $query = $REQUEST->cgi;

    my $usertype = $DB->getType('user');
    return { type => 'freshly_bloodied', error => 'Could not find user type' }
        unless $usertype;

    my $usertype_id = $usertype->{node_id};

    # Get total count of new users this week
    my $sql = "SELECT COUNT(*) FROM node WHERE type_nodetype = ? AND createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK)";
    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($usertype_id);
    my ($total_users) = $sth->fetchrow();

    # Get count of locked users
    $sql = "SELECT COUNT(*) FROM user, node WHERE user_id = node_id AND createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK) AND acctlock != 0";
    $sth = $DB->{dbh}->prepare($sql);
    $sth->execute();
    my ($locked_count) = $sth->fetchrow();

    if (!$locked_count || $locked_count == 0) {
        return {
            type => 'freshly_bloodied',
            total_users => int($total_users || 0),
            locked_count => 0,
            users => [],
            message => 'No locked users this week'
        };
    }

    # Pagination
    my $page_size = 50;
    my $start = int($query->param('start') || 0);
    $start = 0 if $start < 0;

    # Main query - get locked users with locker info
    $sql = qq|
        SELECT user.user_id, user.nick, node.createtime, user.validemail, user.lasttime,
            locker.node_id AS locker_id, locker.title AS locker_name,
            (SELECT notetext FROM nodenote WHERE nodenote_nodeid = user.user_id LIMIT 1) AS notetext
        FROM node
        JOIN user ON node.node_id = user.user_id
        JOIN node AS locker ON locker.node_id = user.acctlock
        WHERE node.createtime > DATE_SUB(NOW(), INTERVAL 1 WEEK)
            AND user.acctlock != 0
        ORDER BY node.createtime DESC
        LIMIT ?, ?
    |;

    $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($start, $page_size);

    my @users;
    while (my $row = $sth->fetchrow_hashref) {
        push @users, {
            user_id     => int($row->{user_id}),
            nick        => $row->{nick},
            createtime  => $row->{createtime},
            lasttime    => $row->{lasttime} || 0,
            validemail  => $row->{validemail} || 0,
            locker_id   => int($row->{locker_id}),
            locker_name => $row->{locker_name},
            notetext    => $row->{notetext} || ''
        };
    }

    return {
        type         => 'freshly_bloodied',
        total_users  => int($total_users),
        locked_count => int($locked_count),
        users        => \@users,
        start        => $start,
        page_size    => $page_size
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
