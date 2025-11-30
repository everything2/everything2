package Everything::Page::buffalo_generator;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::buffalo_generator

React page for Buffalo Generator - generates random buffalo sentences.

Based on the linguistic fact that "Buffalo buffalo Buffalo buffalo buffalo
buffalo Buffalo buffalo" is a grammatically correct English sentence.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $only_buffalo = $REQUEST->param('onlybuffalo') ? 1 : 0;

    return {
        type => 'buffalo_generator',
        only_buffalo => $only_buffalo
    };
}

__PACKAGE__->meta->make_immutable;

1;
