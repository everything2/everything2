package Everything::Page::wharfinger_s_linebreaker;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    # Content-only page - all logic handled client-side in React
    return { type => 'wharfinger_s_linebreaker' };
}

__PACKAGE__->meta->make_immutable;

1;
