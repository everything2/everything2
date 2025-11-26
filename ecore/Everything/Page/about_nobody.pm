package Everything::Page::about_nobody;

use Moose;
extends 'Everything::Page';

sub display {
    return {};
}

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    # Simple React page - all data generated client-side
    # Type is automatically added by Application.pm
    return {};
}

__PACKAGE__->meta->make_immutable;

1;
