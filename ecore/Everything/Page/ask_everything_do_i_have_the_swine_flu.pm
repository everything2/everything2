package Everything::Page::ask_everything_do_i_have_the_swine_flu;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'ask_everything_do_i_have_the_swine_flu'
    };
}

__PACKAGE__->meta->make_immutable;

1;
