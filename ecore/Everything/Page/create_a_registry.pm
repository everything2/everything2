package Everything::Page::create_a_registry;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::create_a_registry - Form to create a new registry

=head1 DESCRIPTION

Allows level 8+ users to create new registries where people can share
information about themselves.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with form configuration.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;

    # Check if guest
    if ($APP->isGuest($USER->NODEDATA)) {
        return {
            type => 'create_a_registry',
            is_guest => 1
        };
    }

    # Check level requirement
    my $level = $APP->getLevel($USER->NODEDATA);
    if ($level < 8) {
        return {
            type => 'create_a_registry',
            level_required => 8,
            current_level => $level
        };
    }

    # User can create registries
    return {
        type => 'create_a_registry',
        can_create => 1,
        input_styles => ['text', 'yes/no', 'date']
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
