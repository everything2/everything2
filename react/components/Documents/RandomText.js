import React, { useState } from 'react'
import ParseLinks from '../ParseLinks'

/**
 * RandomText - Reusable component for random text generators
 *
 * Used by:
 * - fezisms_generator - Random fez quotes in 2 columns
 * - piercisms_generator - Single random pierce quote
 *
 * The quote content lives here now (WIT, keyed on type), not the server -- the pages are pure gates
 * that ship only { type } (#4522). Features: random selection from each array, E2 bracket-link
 * parsing, multi-column layout, regenerate without a page reload.
 */

// Static quote content, keyed on page type. Each value is an array of "arrays to pick one from":
// fezisms picks one from each of two arrays (2-part line); piercisms picks one from its single array.
const WIT = {
  fezisms_generator: [
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
  ],
  piercisms_generator: [
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
  ]
}

const RandomText = ({ data }) => {
  const { type, title, description } = data
  // Content is owned here (#4522), keyed on type; fall back to a server-supplied data.wit for any
  // other caller not yet migrated off shipping it.
  const wit = WIT[type] || data.wit || []

  // Function to randomly select one item from each wit array
  const selectRandomWit = () => wit.map(arr => arr[Math.floor(Math.random() * arr.length)])

  // State for currently displayed quote
  const [selectedWit, setSelectedWit] = useState(selectRandomWit())

  // Layout differences between generators
  const isFezisms = type === 'fezisms_generator'

  // Handler to generate new quote
  const generateNew = () => {
    setSelectedWit(selectRandomWit())
  }

  return (
    <div className="random-text-generator">
      {title && <h2>{title}</h2>}
      {description && <p>{description}</p>}

      <div className="random-text-generator__display">
        {isFezisms ? (
          // Fezisms: Multi-part horizontal layout (2 columns)
          <div className="random-text-generator__text">
            {selectedWit.map((text, index) => (
              <React.Fragment key={index}>
                <ParseLinks text={text} />
                {index < selectedWit.length - 1 && ' '}
              </React.Fragment>
            ))}
          </div>
        ) : (
          // Piercisms: Single large centered text
          <div className="random-text-generator__text--large">
            <ParseLinks text={selectedWit[0]} />
          </div>
        )}
      </div>

      <div className="random-text-generator__button-container">
        <button
          onClick={generateNew}
          className="random-text-generator__button"
        >
          Generate Another
        </button>
      </div>
    </div>
  )
}

export default RandomText
