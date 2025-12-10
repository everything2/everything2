package Everything::Page::registry_information;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::registry_information - Show user's own registry entries

=head1 DESCRIPTION

Displays all registry entries for the current user, allowing them to see
what registries they have submitted data to.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with user's registry entries.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Check if guest
    if ($APP->isGuest($USER->NODEDATA)) {
        return {
            type => 'registry_information',
            is_guest => 1
        };
    }

    # Get user's registry entries
    my $csr = $DB->sqlSelectMany(
        '*',
        'registration',
        'from_user=' . $USER->node_id
    );

    return {
        type => 'registry_information',
        error => 'Database error'
    } unless $csr;

    my @entries = ();
    while (my $ref = $csr->fetchrow_hashref()) {
        my $registry = $DB->getNodeById($ref->{for_registry});
        next unless $registry;

        push @entries, {
            registry => {
                node_id => $registry->{node_id},
                title => $registry->{title}
            },
            data => $APP->htmlScreen($ref->{data} || ''),
            comments => $APP->htmlScreen($ref->{comments} || ''),
            in_profile => $ref->{in_user_profile} ? 1 : 0
        };
    }

    return {
        type => 'registry_information',
        entries => \@entries,
        has_entries => scalar(@entries) > 0 ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
