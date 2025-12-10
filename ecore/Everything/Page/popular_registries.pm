package Everything::Page::popular_registries;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::popular_registries - Show most popular registries by submission count

=head1 DESCRIPTION

Displays a list of registries sorted by the number of submissions they have received.
Shows the top 25 registries with the most entries.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with list of popular registries.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $limit = 25;

    # Get registries ordered by submission count
    my $query = q{
        SELECT
            r.for_registry,
            COUNT(r.for_registry) AS submission_count
        FROM registration r
        GROUP BY r.for_registry
        ORDER BY submission_count DESC
        LIMIT ?
    };

    my $sth = $DB->{dbh}->prepare($query);
    $sth->execute($limit);

    my @registries = ();
    while (my $row = $sth->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($row->{for_registry});
        next unless $registry;

        push @registries, {
            node_id => $registry->{node_id},
            title => $registry->{title},
            submission_count => $row->{submission_count}
        };
    }

    return {
        type => 'popular_registries',
        registries => \@registries,
        limit => $limit
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
