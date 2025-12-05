package Everything::Page::level_distribution;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::level_distribution - Level Distribution Statistics

=head1 DESCRIPTION

Shows the number of active E2 users at each level (based on users logged in over the last month).

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with level distribution counts.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Query active users (logged in within last month)
    my $sql = qq{
        SELECT u.user_id
        FROM user u
        WHERE u.lasttime >= DATE_ADD(CURDATE(), INTERVAL -1 MONTH)
    };

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    # Get level titles
    my $lvlttl_node = $DB->getNode('level titles', 'setting');
    my $lvlttl = $APP->getVars($lvlttl_node);

    # Count users by level
    my %levels;
    while (my $row = $sth->fetchrow_hashref()) {
        my $user_node = $DB->getNodeById($row->{user_id});
        my $level = $APP->getLevel($user_node);
        $levels{$level}++;
    }

    $sth->finish();

    # Convert to array sorted by count (descending)
    my @level_data;
    foreach my $level_num (sort { $levels{$b} <=> $levels{$a} } keys %levels) {
        push @level_data, {
            level => $level_num,
            title => $lvlttl->{$level_num} || '',
            count => $levels{$level_num}
        };
    }

    return {
        type => 'level_distribution',
        levels => \@level_data
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
