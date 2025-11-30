package Everything::Page::buffalo_haiku_generator;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::buffalo_haiku_generator

React page for Buffalo Haiku Generator - generates haiku using buffalo words.

Generates 5-7-5 syllable haiku using verb-nouns like buffalo, police,
bream, perch, etc.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $only_buffalo = $REQUEST->param('onlybuffalo') ? 1 : 0;

    return {
        type => 'buffalo_haiku_generator',
        only_buffalo => $only_buffalo
    };
}

__PACKAGE__->meta->make_immutable;

1;
