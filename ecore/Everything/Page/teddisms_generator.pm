package Everything::Page::teddisms_generator;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'teddisms_generator'
    };
}

__PACKAGE__->meta->make_immutable;

1;
