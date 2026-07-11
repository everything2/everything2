package Everything::Page::e2node_reparenter;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::e2node_reparenter

React page for the E2Node Reparenter. Reuses the MagicalWriteupReparenter React component (returns
type => 'magical_writeup_reparenter'). Pure gate: it ships only the access decision + type; React
reads the lookup params (including the legacy C<repare> source param) off the URL and resolves them
via GET /api/writeup_reparent (#4502).

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    # Editors only (admins are editors). access_denied runs in buildReactData, so it gates the
    # /api/pagestate path too; the API is the real enforcement boundary for the lookup + move.
    return { type => 'magical_writeup_reparenter', access_denied => 1 }
        unless $REQUEST->user->is_editor;

    return { type => 'magical_writeup_reparenter' };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::magical_writeup_reparenter>, L<Everything::API::writeup_reparent>

=cut
