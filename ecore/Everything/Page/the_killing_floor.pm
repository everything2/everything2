package Everything::Page::the_killing_floor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_killing_floor - Deprecated editorial tool (preserved for site integrity)

=head1 DESCRIPTION

The Killing Floor was a legacy editorial tool that is no longer used by the editing system.
This page is preserved for technical site integrity but has no active functionality.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data indicating this is a deprecated page.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'the_killing_floor',
        title => 'The Killing Floor',
        deprecated => 1
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
