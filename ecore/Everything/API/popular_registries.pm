package Everything::API::popular_registries;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::popular_registries - registries ranked by number of submissions

=head1 DESCRIPTION

The top 25 registries by registration count. Moved out of
C<Everything::Page::popular_registries>'s buildReactData (#4550): the Page is a pure gate. Public.

  GET /api/popular_registries

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB    = $self->DB;
    my $limit = 25;

    my $dbh = $DB->getDatabaseHandle();
    my $sth = $dbh->prepare(q{
        SELECT r.for_registry, COUNT(r.for_registry) AS submission_count
        FROM registration r
        GROUP BY r.for_registry
        ORDER BY submission_count DESC
        LIMIT 25
    });
    $sth->execute();

    my @registries;
    while (my $row = $sth->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($row->{for_registry});
        next unless $registry;
        push @registries, {
            node_id          => int($registry->{node_id}),
            title            => $registry->{title},
            submission_count => int($row->{submission_count}),
        };
    }
    $sth->finish();

    return [$self->HTTP_OK, { success => 1, registries => \@registries, limit => $limit }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
