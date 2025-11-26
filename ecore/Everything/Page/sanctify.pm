package Everything::Page::sanctify;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $USER = $REQUEST->user;

    # Type is automatically added by Application.pm
    # Note: GP and GPOptout available in e2.user (global)
    return { sanctity => $USER->sanctity };
}

__PACKAGE__->meta->make_immutable;

1;
