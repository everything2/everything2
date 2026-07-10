package Everything::Page::websterbless;

use Moose;
extends 'Everything::Page';
with 'Everything::Roles::Bestow';

=head1 Everything::Page::websterbless

React page for Websterbless - rewards users who suggest corrections to Webster 1913.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    # Soft gate: editors only (admins are editors, so is_editor covers both). Return a blank
    # { type => 'staff_only' }; React (StaffOnly.js) owns the friendly copy -- no "Access denied…"
    # string in the payload (#4497).
    #
    # INTERIM: this is an inline check ON PURPOSE for now. The self-documenting-mixin form
    # (`with 'Everything::Security::StaffOnly'`) is deferred to the post-audit permissions
    # consolidation, because that mixin's check_permission only gates the page-render controller
    # (Controller/superdoc.pm) -- it does NOT yet gate the /api/pagestate path, which this Page's
    # buildReactData feeds too. An inline check here gates BOTH paths; the mixin swap lands when the
    # consolidation makes the gate cover the pagestate/API path as well.
    return { type => 'staff_only' } unless $REQUEST->user->is_editor;

    # Webster 1913 read data (webster_id + msg_count) via Everything::Roles::Bestow -- the page
    # no longer calls $DB directly (#4497). webster_payload carries { error } instead if the
    # Webster account is missing; either way the page just merges it into the return hash.
    #
    # NB: the `prefill_username` URL hint is NOT read here -- prefilling a form field from the
    # query string is a pure client concern, so React reads it off window.location directly
    # (Websterbless.js). The server neither reads nor ships it. The bless WRITE likewise lives in
    # POST /api/websterbless/bless (#4451). This page is now just: gate -> role read -> shape.
    return { type => 'websterbless', %{ $self->webster_payload } };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
