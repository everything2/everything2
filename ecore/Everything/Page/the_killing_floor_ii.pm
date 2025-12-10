package Everything::Page::the_killing_floor_ii;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_killing_floor_ii - Deprecated editorial tool (preserved for site integrity)

=head1 DESCRIPTION

The Killing Floor II was a legacy editorial tool that is no longer used by the editing system.
This page is preserved for technical site integrity but has no active functionality.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data indicating this is a deprecated page.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'the_killing_floor_ii',
        title => 'The Killing Floor II',
        deprecated => 1
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
