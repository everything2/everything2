package Everything::Page::e2_acceptable_use_policy;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    return {};
}

__PACKAGE__->meta->make_immutable;

1;
