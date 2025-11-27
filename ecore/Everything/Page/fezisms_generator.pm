package Everything::Page::fezisms_generator;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    # Fezisms wit arrays - randomly select one from each array
    my $wit = [
        [
            "[The Fez is Responsible for Global Warming|DADDY NEEDS SOME]",
            "[I actually, um, created, um, thefez|GLOOPY GLOBS OF]",
"[thefez may be an ape but he does not know sign language and we certainly do not trust him with kittens|HOLY FUCKLOADS OF]",
            "[Enjoying Sex - Female|I JUST STEPPED IN]",
            "[You know it is going to be a long day when...|WHAT'S UP WITH]",
"[A huge fierce green snake bars the way!|I GOTS ME A FIST FULL OF]",
            "[natural outlaws|THE WHOLE MESS TURNED INTO]",
"[Alexander the Great and the Terrible, Horrible, No-Good Very Bad|THIS GUY GAVE ME]",
            "[Underground Tokyo (overview)|NOBODY GETS MY]",
            "[Desecrator|EVERYONE CLAIMS TO SEE]",
            "[Inbeing|WHO WANTS A PIECE OF MY]",
            "[Patton's Speech to the Third Army|DIDJA EVER HEAR THE ONE ABOUT]",
            "[The Evil Overlord list|DON'T RUB ON MY]",
"[i have five things to say|LISTEN TO THE GLEEFUL GIBBERINGS OF THE]",
            "[Yossarian's School of Badassary|I SHOT A NODER IN RENO JUST FOR]",
            "[The Lincoln County War|YOU STEP BACK AND FILL THE VOID WITH]",
"[I actually, um, created, um, thefez. It's true.|EVERYTHING I EVER LEARNED ABOUT ILLUSION WAS FROM]",
"[almost every conspiracy I can think of started in thefez's crazed version of reality|GIANT CYBORGICAL]",
"[the imaginary world where I make up things and they are true|MIDEGET PORN STARS WITH]",
"[A person shouldn't believe in isms, they should believe in thefez|SUPER DUPER SNAZZY]",
"[SOY! SOY! SOY! soy makes you strong! strength crushes enemies! SOY!|SMACK DAB IN THE MIDDLE OF]",
"[SUPER KARATE MONKEY DEATH CAR|WHEN JESUS BUILT ME HE FORGOT ALL THE]",
"[oh boner, you didn't whiz on old glory, did you?|MY MIDGET WENT TO HELL AND ALL IT GOT ME WERE THESE STINKIN']"
        ],
        [
            "[giant mechanical spiders|HUMAN HEADS!]",
            "[letters from a savior; offer for a few|HUMAN HEARTS!]",
            "[The fez...episode one|NINJA BONGS!]",
            "[everything 2 civil war|BASTARDASSES!]",
            "[BIG FAT HAIRY VISION OF EVIL|BIG FAT HAIRY VISION OF EVIL!]",
            "[anger, shaped like a man|PISS FOAM!]",
            "[Lesbians! Monkeys! Soy!|SOY! SOY! SOY!]",
            "[mutual funds|BITCH NUGGETS!]",
"[and lo, the phoenix shall hatcheth, and burrow through ye arse with fiery abandon!|NINJA ASS TRICKS!]",
            "[Everything Commune|PEACE, MONEY AND SPACESHIPS!]",
            "[Everything MUD|THREE OF FIVE EXPERIMENTS DYING BEFORE BIRTH!]",
            "[soul aikido|SPACE HIPPIE VOODOO]",
            "[Everyone has a dead bird story|PATENTED SPIRIT MANGLER!]",
            "[Balki-isms|FOREIGN DESPOTS!]",
            "[What's wrong with that lawnjart kid anyway?|FRIENDLY ASSASSINS!]",
            "[A dangerous evening in Canada|ILLEGAL GENETIC MODIFICATIONS!]",
"[Philosophy won't keep you warm at night.|TRANSCENDENTAL MONKEY VIBRATIONS!]",
            "[fezisms generator|GLORIOUS EVIL SQUISHY THINGS!]",
"[thefez haunts the node mountain|FULLY ACCREDITED SPIRITUAL MISFITS!]",
            "[everything drugs|SECONAL AND SPANISH FLY!]",
            "[spiders with human heads!|SEX MITTENS!]",
"[SUITCASE-SIZED NUCLEAR DEMOLITIONS DEVICES|SUITCASE-SIZED NUCLEAR DEMOLITIONS DEVICES!]"
        ]
    ];

    return {
        type => 'fezisms_generator',
        wit  => $wit
    };
}

__PACKAGE__->meta->make_immutable;

1;
