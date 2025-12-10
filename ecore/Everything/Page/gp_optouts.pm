package Everything::Page::gp_optouts;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::gp_optouts - Display users who have opted out of the GP system

=head1 DESCRIPTION

Admin tool showing a list of users who have opted out of receiving GP (Group Points).
Displays username, level, and current GP for each opted-out user.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns list of users who have GPoptout enabled in their VARS.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Query for users with GPoptout enabled
    my $query_text = "SELECT user.user_id, user.GP FROM setting, user " .
                     "WHERE setting.setting_id = user.user_id " .
                     "AND setting.vars LIKE '%GPoptout=1%'";

    my $rows = $DB->{dbh}->prepare($query_text);
    unless ($rows) {
        return {
            type => 'gp_optouts',
            error => 'Database query failed: ' . $DB->{dbh}->errstr,
            users => []
        };
    }

    unless ($rows->execute()) {
        return {
            type => 'gp_optouts',
            error => 'Query execution failed: ' . $rows->errstr,
            users => []
        };
    }

    my @users = ();
    while (my $row = $rows->fetchrow_arrayref) {
        my $user_id = $row->[0];
        my $gp = $row->[1];
        my $user_node = $DB->getNodeById($user_id);

        next unless $user_node;

        my $level = $APP->getLevel($user_node) || 0;

        push @users, {
            user_id => int($user_id),
            username => $user_node->{title},
            level => int($level),
            gp => int($gp)
        };
    }

    # Sort by username (case-insensitive)
    @users = sort { lc($a->{username}) cmp lc($b->{username}) } @users;

    return {
        type => 'gp_optouts',
        users => \@users
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
