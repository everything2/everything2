package Everything::Page::recent_users;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::recent_users - List users who logged in within the last 24 hours

=head1 DESCRIPTION

"Recent Users" displays a list of all users who have logged in to the site
within the last 24 hours, sorted alphabetically by username. Shows staff
badges (admin @, editor $, chanop +) next to usernames.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns a list of users who logged in within the last 24 hours.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Query users who logged in within last 24 hours
    my $csr = $DB->sqlSelectMany(
        "user.user_id",
        "user, node",
        "user.user_id = node.node_id AND lasttime >= DATE_SUB(NOW(), INTERVAL 1 DAY)",
        "ORDER BY node.title"
    );

    my @users = ();

    if ($csr) {
        while (my $row = $csr->fetchrow_hashref()) {
            my $user_node = $DB->getNodeById($row->{user_id});
            next unless $user_node;

            # Check staff status
            my $is_admin = $APP->isAdmin($user_node) ? 1 : 0;
            my $is_editor = $APP->isEditor($user_node, "nogods") ? 1 : 0;
            my $is_chanop = $APP->isChanop($user_node, "nogods") ? 1 : 0;

            # Check if user hides their staff symbol
            my $hide_symbol = $APP->getParameter($user_node, "hide_chatterbox_staff_symbol") ? 1 : 0;

            push @users, {
                user_id => $user_node->{node_id},
                username => $user_node->{title},
                is_admin => $is_admin && !$hide_symbol ? 1 : 0,
                is_editor => $is_editor && !$hide_symbol ? 1 : 0,
                is_chanop => $is_chanop,
                lasttime => $user_node->{lasttime}
            };
        }
    }

    return {
        users => \@users,
        user_count => scalar(@users)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
