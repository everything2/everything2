package Everything::Page::magical_writeup_reparenter;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::magical_writeup_reparenter

React page for the Magical Writeup Reparenter (editors/admins move writeups between e2nodes).
Pure gate: it ships only the access decision + type. React (MagicalWriteupReparenter) reads the
lookup params off the URL and resolves them client-side via GET /api/writeup_reparent (#4502).

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

L<Everything::Page>, L<Everything::API::writeup_reparent>

=cut
