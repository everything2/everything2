package Everything::Page::my_recent_writeups;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::my_recent_writeups - My Recent Writeups page

=head1 DESCRIPTION

Displays the number of writeups the logged-in user has published in the past year.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about user's recent writeup count.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;

    # Guest users get a message
    if ($USER->is_guest) {
        return {
            type => 'my_recent_writeups',
            is_guest => 1,
            message => "If you logged in, you would know how many writeups you've published recently."
        };
    }

    my $user_id = $USER->{node_id};

    # Calculate one year ago timestamp
    my $one_year_ago = time() - 31536000;

    # Format the date (simple format without user timezone preferences)
    my @months = qw(January February March April May June July August September October November December);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday) = localtime($one_year_ago);
    my $one_year_ago_formatted = ('Sun','Mon','Tues','Wednes','Thurs','Fri','Satur')[$wday].'day, ' .
                                  $months[$mon] . ' ' . $mday . ', ' . (1900+$year);

    # Build exclusion list for maintenance nodes
    my $not_in = "";
    my @maintenance_ids = grep { /^\d+$/ } @{$Everything::CONF->maintenance_nodes || []};
    if (@maintenance_ids) {
        $not_in = " AND node.node_id NOT IN (" . join(', ', @maintenance_ids) . ")";
    }

    # Count writeups published in the last year
    my $sql = "SELECT COUNT(*)
        FROM node JOIN writeup ON writeup.writeup_id=node.node_id
        WHERE publishtime > (NOW() - INTERVAL 1 YEAR)
        AND author_user=? $not_in";

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($user_id);
    my ($count) = $sth->fetchrow;

    return {
        type => 'my_recent_writeups',
        is_guest => 0,
        writeup_count => $count,
        one_year_ago => $one_year_ago_formatted,
        user_id => $user_id,
        username => $USER->{title}
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
