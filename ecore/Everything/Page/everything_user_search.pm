package Everything::Page::everything_user_search;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_user_search - Browse writeups by user

=head1 DESCRIPTION

Pure gate: ships only { type }. React (UserSearch) reads the search params (usersearch, orderby,
page, filterhidden) off the URL, resolves suggestions via the shared autofill (GET /api/node_search),
and fetches results via GET /api/user_search. No param reading or resolution here (#4506). The legacy
orderby-format mapping the Page used to apply now lives client-side in UserSearch.js.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;
    return { type => 'everything_user_search' };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::API::user_search>, L<Everything::API::node_search>

=cut
