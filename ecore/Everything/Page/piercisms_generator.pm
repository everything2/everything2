package Everything::Page::piercisms_generator;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    # Piercisms wit array - randomly select one
    my $wit = [
        [
            "[I give myself|Nipple]",
            "[The View From My Room|Croony]",
            "[Dr. Brightman|Swoon]",
            "[Because I dig you|Ninny]",
            "[I break myself down|Pleasant]",
            "[Tell me a story about trains.|Joy]",
            "[Tell me why you're an idiot|Pickle]",
            "[I was once stranded on a desert island|Poodle]",
            "[nodes i like|Poop]",
            "[drowning in time|Woogums]",
            "[deconstructing datagirl|Silly]",
            "[nodes that may make you feel better|Honey]",
            "[suicide is painless|Muffin]",
            "[How do men touch you?|Woogle]",
            "[things to do to salvage a shitty day|Snargle]",
            "[yay!|Wiggly]",
            "[one is the loneliest number|Cuddle]",
"[my heart feels filled with warm water when I think of these things|Schnooker]",
            "[Only Slightly a Geek Girl|Cruller]",
            "[Why I should be the female voice of slashdot|Mutton]",
            "[January 24, 2000|Snifter]",
            "[the funniest thing i've seen today|Goober]",
            "[I give myself|Snapple]",
            "[life after god|Bunny]",
            "[Tierlon|Foggy]",
            "[Spare Key Savior|Wiggly]",
            "[Copper Starlight|Mister]",
            "[Yay for pie!|Sookie]",
            "[wandering the toronto eaton center|Smackle]",
            "[my first kiss|Ripply]",
            "[ownership kiss|Moogie]"
        ]
    ];

    return {
        type => 'piercisms_generator',
        wit  => $wit
    };
}

__PACKAGE__->meta->make_immutable;

1;
