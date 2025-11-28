import React, { useMemo } from 'react'

/**
 * What to Do if E2 Goes Down - Humorous downtime suggestions
 *
 * Phase 4a migration from Mason template what_to_do_if_e2_goes_down.mc
 * Shows: Random suggestion from curated list of activities
 *
 * Content-Only Optimization: Suggestions array lives in React instead of Perl
 * - Reduces Perl library size (no data arrays in .pm files)
 * - Eliminates server processing (random selection happens client-side)
 * - Better for CDN caching (static React bundles)
 * - Simpler architecture (pure client-side rendering)
 */
const WhatToDoIfE2GoesDown = () => {
  // Static content moved from Perl to React for content-only optimization
  const suggestions = [
    'Go outside',
    'Take off all your clothes',
    'Go outside',
    'Go outside',
    'Read a book',
    'Pour another round',
    'Think of something to node',
    'show up in #everything and bitch about it',
    'RUN AROUND YOUR HOUSE LIKE A SCARED IDIOT',
    'Have some tuna casserole',
    'Memorize <em>West Side Story</em>',
    'Learn perl',
    'Find something else on the Internet',
    'Write emails to yourself',
    'Go outside',
    'Make a sandwich',
    'Go out on a date',
    'Find another human being and engage in conversation. In person, if at all possible.',
    "Change the cat's litterbox",
    'Paint a picture',
    'Go outside',
    'Take a roadtrip',
    'Pee in the company coffee-pot',
    'Knit a scarf',
    'Bake a pie',
    'Write a sonata in F# minor',
    'Clean your room',
    'Reorganize your CD collection',
    'Go outside',
    'Take the beer bottles that have been collecting in your kitchen to the nearest place at which they can be redeemed for cash',
    'Find Buddha on the road. Then kill him.',
    'Fuck wit Don',
    'Enroll in a massage therapy course',
    'ACCESS THIS PAGE IMMEDIATELY FOR SPECIAL BACKUP SERVER ADDRESS INFORMATION',
    'Make a pig out of four pins and an eraser',
    'Bootleg gin',
    'Restore Order to the Balance',
    'Restore Balance to the Order',
    'Work on your spider scratch',
    'Hold your breath',
    'Eat a sandwich',
    'Enjoy a refreshing beverage',
    'Enjoy a zesty babaghanoush',
    'Enjoy a mouthwatering chicken-fried steak',
    'Drink two 8-ounce glasses of water',
    'Try to count boobies on scrambled porn',
    'Chill the fuck out',
    'Eat the rich',
    'Visit Wikipedia',
    'Turn off your computer and cry',
    'Call your mother',
    'Inject heroin into your eyeball',
    'Go sledding',
    'Taste the rainbow',
    'Bake a delicious cake',
    'Come',
    'Go outside',
    'Fill out these forms',
    'Smoke a ronny',
    'Build relationships',
    'Mingle',
    "Play 'Swat the Kitty'",
    'Ride, ride, ride, let it ride',
    'Have a seat, and dannye will be right with you',
    'Order some stuff of the TV',
    "Reappropriate Sis's wardrobe",
    "Find a large group of people.  Say 'Hey, guys, look at this!'  This will get their attention.  Then throw an imaginary ball in the air and watch as their eyes try to follow it.",
    'Grow',
    'Bite my crank',
    'Unleash the Dark Army',
    'Pray to the gods',
    'Replace the filter in the sump pump',
    'Take your pill',
    'Reinvent the wheel',
    'Learn new words',
    'Aspire to reinnervate on a cut that reverberates',
    'Bite the wax tadpole',
    "Dance like there's ass in your pants",
    'Undergo meme adjustment therapy',
    'Eat something, skinny',
    'Interpret Nostradamus',
    'Invent a delicious recipe involving these components: mongolian fire oil, flax, barbecue sauce',
    'Find a job',
    'Play the ressurector and give the dead some life',
    'Clean your tongue',
    'Expel gas from your rectum',
    'Summon a being whose name your feeble human tongue can barely pronounce',
    "Run! You're free! FREE!",
    'Memorize West Side Story'
  ]

  // Client-side random selection (was previously done in Perl)
  const suggestion = useMemo(
    () => suggestions[Math.floor(Math.random() * suggestions.length)],
    [] // Select once on mount, stable across re-renders
  )

  return (
    <div
      className="what-to-do-if-e2-goes-down"
      style={{ textAlign: 'center', padding: '40px 20px' }}
    >
      <p style={{ marginBottom: '40px' }}>
        Hey. <em>It happens</em>. Sit back. Relax. It'll get fixed. If you think that it may not
        have been reported yet, email the e2webmaster account. In the meantime...
      </p>
      <div
        style={{
          fontSize: '32px',
          fontWeight: 'bold',
          lineHeight: '1.4'
        }}
      >
        {suggestion}
      </div>
    </div>
  )
}

export default WhatToDoIfE2GoesDown
