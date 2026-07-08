package Everything::Page::notelet_editor;

use Moose;
extends 'Everything::Page';

with 'Everything::Roles::Notelet';

=head1 NAME

Everything::Page::notelet_editor - Notelet Editor for managing user notelet content

=head1 DESCRIPTION

Provides two self-service features, both now driven by POST /api/notelet (#4479, Refs #4298):

1. Notelet Castrator - comments out all JavaScript in the notelet
2. Notelet Editor - edits the noteletRaw VARS field with per-level character limits

This controller is pure-render: the save/castrate WRITES moved to Everything::API::notelet so
rendering the page no longer mutates the user's VARS off query params. The display payload +
level-based max length are shared with the API via Everything::Roles::Notelet.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns the current (read-only) notelet display data.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'notelet_editor',
        %{ $self->notelet_payload($REQUEST->user) },
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::notelet>, L<Everything::Roles::Notelet>

=cut
