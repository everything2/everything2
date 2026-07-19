package Everything::API::the_registries;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::the_registries - registries ranked by most recent entry

=head1 DESCRIPTION

Lists registries (optionally including empty ones) ordered by their most recent registration. Moved
out of C<Everything::Page::the_registries>'s buildReactData (#4548): the Page is a pure gate, React
reads C<include_empty> off the URL and calls this. Login-required (NoGuest).

  GET /api/the_registries?include_empty=1

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $include_empty = $REQUEST->param('include_empty') ? 1 : 0;

    my $csr = $include_empty
        ? $DB->sqlSelectMany(
            'registry.registry_id, COUNT(registration.for_registry) as entry_count, MAX(registration.tstamp) as last_entry',
            'registry LEFT JOIN registration ON registry.registry_id = registration.for_registry',
            '1=1',
            'GROUP BY registry.registry_id ORDER BY last_entry DESC, registry.registry_id DESC LIMIT 200')
        : $DB->sqlSelectMany(
            'registry.registry_id, COUNT(registration.for_registry) as entry_count, MAX(registration.tstamp) as last_entry',
            'registry, registration',
            'registry.registry_id = registration.for_registry',
            'GROUP BY registration.for_registry ORDER BY last_entry DESC LIMIT 100');

    my @registries;
    while (my $ref = $csr->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($ref->{registry_id});
        next unless $registry;
        push @registries, {
            node_id     => int($registry->{node_id}),
            title       => $registry->{title},
            entry_count => int($ref->{entry_count} || 0),
        };
    }

    return [$self->HTTP_OK, {
        success       => 1,
        registries    => \@registries,
        count         => scalar(@registries),
        include_empty => $include_empty ? \1 : \0,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
