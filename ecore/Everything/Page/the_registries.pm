package Everything::Page::the_registries;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_registries - List registries by most recent entry

=head1 DESCRIPTION

Shows all registries that have entries, ordered by most recent entry date.
Optionally includes empty registries via the include_empty query parameter.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with registries list.

Query parameters:
  include_empty - If set to 1, includes registries with no entries

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $CGI = $REQUEST->cgi;

    # Check if guest
    if ($APP->isGuest($USER->NODEDATA)) {
        return {
            type => 'the_registries',
            is_guest => 1
        };
    }

    # Check if we should include empty registries
    my $include_empty = $CGI->param('include_empty') ? 1 : 0;

    my @registries = ();

    if ($include_empty) {
        # Get ALL registries with entry counts using LEFT JOIN
        my $csr = $DB->sqlSelectMany(
            'registry.registry_id, COUNT(registration.for_registry) as entry_count, MAX(registration.tstamp) as last_entry',
            'registry LEFT JOIN registration ON registry.registry_id = registration.for_registry',
            '1=1',
            'GROUP BY registry.registry_id ORDER BY last_entry DESC, registry.registry_id DESC LIMIT 200'
        );

        return {
            type => 'the_registries',
            error => 'Database error'
        } unless $csr;

        while (my $ref = $csr->fetchrow_hashref()) {
            my $registry = $DB->getNodeById($ref->{registry_id});
            next unless $registry;

            push @registries, {
                node_id => $registry->{node_id},
                title => $registry->{title},
                entry_count => $ref->{entry_count} || 0
            };
        }
    } else {
        # Get only registries with entries (original behavior)
        my $csr = $DB->sqlSelectMany(
            'registry.registry_id, COUNT(registration.for_registry) as entry_count, MAX(registration.tstamp) as last_entry',
            'registry, registration',
            'registry.registry_id = registration.for_registry',
            'GROUP BY registration.for_registry ORDER BY last_entry DESC LIMIT 100'
        );

        return {
            type => 'the_registries',
            error => 'Database error'
        } unless $csr;

        while (my $ref = $csr->fetchrow_hashref()) {
            my $registry = $DB->getNodeById($ref->{registry_id});
            next unless $registry;

            push @registries, {
                node_id => $registry->{node_id},
                title => $registry->{title},
                entry_count => $ref->{entry_count} || 0
            };
        }
    }

    return {
        type => 'the_registries',
        registries => \@registries,
        count => scalar(@registries),
        include_empty => $include_empty
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
