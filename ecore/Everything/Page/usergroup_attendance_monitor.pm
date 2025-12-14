package Everything::Page::usergroup_attendance_monitor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::usergroup_attendance_monitor - Monitor usergroup membership activity

=head1 DESCRIPTION

Admin tool showing users in usergroups who haven't logged in for over 365 days.
Helps identify inactive usergroup members who may need removal.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'usergroup_attendance_monitor',
            error => 'This page is restricted to administrators.'
        };
    }

    # Get all usergroups and their members
    my $usergroup_type = $DB->getType('usergroup');
    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=" . $usergroup_type->{node_id});

    my $people = {};
    while (my $row = $csr->fetchrow_hashref) {
        my $N = $DB->getNodeById($row->{node_id});
        next unless $N && $N->{group};

        foreach my $member_id (@{$N->{group}}) {
            $people->{$member_id} ||= [];
            push @{$people->{$member_id}}, {
                group_id    => int($N->{node_id}),
                group_title => $N->{title}
            };
        }
    }
    $csr->finish;

    # Find users who haven't logged in for over 365 days
    my @inactive_users = ();

    foreach my $uid (keys %$people) {
        my $p = $DB->sqlSelect("user_id", "user", "user_id=$uid and TO_DAYS(NOW()) - TO_DAYS(lasttime) > 365");
        next unless $p;

        my $user_node = $DB->getNodeById($p);
        next unless $user_node;

        my @groups_with_status = ();
        foreach my $grp (@{$people->{$p}}) {
            my $is_ignored = $DB->sqlSelect(
                "messageignore_id",
                "messageignore",
                "messageignore_id=$p and ignore_node=" . $grp->{group_id}
            );
            push @groups_with_status, {
                group_id    => $grp->{group_id},
                group_title => $grp->{group_title},
                is_ignored  => $is_ignored ? 1 : 0
            };
        }

        push @inactive_users, {
            user_id    => int($p),
            user_title => $user_node->{title},
            groups     => \@groups_with_status
        };
    }

    # Sort by username
    @inactive_users = sort { lc($a->{user_title}) cmp lc($b->{user_title}) } @inactive_users;

    return {
        type           => 'usergroup_attendance_monitor',
        inactive_users => \@inactive_users,
        count          => scalar(@inactive_users)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
