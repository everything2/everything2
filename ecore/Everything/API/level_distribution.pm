package Everything::API::level_distribution;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::level_distribution - active users per level

=head1 DESCRIPTION

Public count of active users (logged in within the last month) at each level, with level titles.
Moved out of C<Everything::Page::level_distribution>'s buildReactData (#4546): the Page is a pure gate.

  GET /api/level_distribution

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare(qq{
        SELECT u.user_id
        FROM user u
        WHERE u.lasttime >= DATE_ADD(CURDATE(), INTERVAL -1 MONTH)
    });
    $sth->execute();

    my $lvlttl = $APP->getVars($DB->getNode('level titles', 'setting'));

    my %levels;
    while (my $row = $sth->fetchrow_hashref()) {
        my $user_node = $DB->getNodeById($row->{user_id});
        next unless $user_node;
        my $level = $APP->getLevel($user_node);
        $levels{$level}++;
    }
    $sth->finish();

    my @level_data;
    foreach my $level_num (sort { $levels{$b} <=> $levels{$a} } keys %levels) {
        push @level_data, {
            level => int($level_num),
            title => $lvlttl->{$level_num} || '',
            count => int($levels{$level_num}),
        };
    }

    return [$self->HTTP_OK, { success => 1, levels => \@level_data }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
