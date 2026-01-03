package Everything::Page::recalculated_users;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Find users who have run Recalculate XP
    my $sql = q{
        SELECT user.user_id, user.experience
        FROM setting, user
        WHERE setting.setting_id = user.user_id
        AND setting.vars LIKE '%hasRecalculated=1%'
    };

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute();

    my @users;
    while (my $row = $sth->fetchrow_arrayref) {
        my $user_id = $row->[0];
        my $xp = $row->[1];
        my $user_node = $APP->node_by_id($user_id);

        next unless $user_node;

        push @users, {
            node_id => int($user_id),
            title   => $user_node->title,
            level   => int($APP->getLevel($user_id)),
            xp      => int($xp || 0),
        };
    }

    # Sort by username (case-insensitive)
    @users = sort { lc($a->{title}) cmp lc($b->{title}) } @users;

    return {
        recalculatedUsers => {
            users => \@users,
            count => scalar(@users),
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
