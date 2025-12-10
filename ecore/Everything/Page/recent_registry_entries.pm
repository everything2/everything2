package Everything::Page::recent_registry_entries;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::recent_registry_entries - Show recent registry entries across all registries

=head1 DESCRIPTION

Displays the most recent 100 registry entries from all registries.
Requires login to view.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with list of recent registry entries.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Check if guest
    if ($APP->isGuest($USER->NODEDATA)) {
        return {
            type => 'recent_registry_entries',
            is_guest => 1
        };
    }

    # Get recent registry entries
    my $csr = $DB->sqlSelectMany(
        '*',
        'registration',
        '',
        'ORDER BY tstamp DESC LIMIT 100'
    );

    return {
        type => 'recent_registry_entries',
        error => 'Database error'
    } unless $csr;

    my @entries = ();
    while (my $ref = $csr->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($ref->{for_registry});
        my $user_node = $DB->getNodeById($ref->{from_user});

        next unless $registry && $user_node;

        # Sanitize data and comments
        my $data = $APP->parseAsPlainText($ref->{data} || '');
        my $comments = $APP->parseAsPlainText($ref->{comments} || '');

        push @entries, {
            registry => {
                node_id => $registry->{node_id},
                title => $registry->{title}
            },
            user => {
                node_id => $user_node->{node_id},
                title => $user_node->{title}
            },
            data => $data,
            comments => $comments,
            in_profile => $ref->{in_user_profile} ? 1 : 0,
            timestamp => $ref->{tstamp}
        };
    }

    return {
        type => 'recent_registry_entries',
        entries => \@entries
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
