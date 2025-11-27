import React, { useMemo } from 'react'

// Oblique Strategies by Brian Eno and Peter Schmidt
// Original card deck for creative problem-solving
const STRATEGIES = [
  '(BLANK CARD)',
  '(Organic) Machinery',
  'A line has two sides',
  'A very small object         Its center',
  'Abandon normal instruments',
  'Accept advice',
  'Accretion',
  'Allow an easement (an easement is the abandonment of a structure)',
  'Always first steps',
  'Always give yourself credit for having more than personality',
  'Are there sections ? Consider transitions',
  'Ask people to work against their better judgment',
  'Ask your body',
  'Assemble some of the elements in a group and treat the group',
  'Balance the consistency principle with the inconsistency principle',
  'Be dirty',
  'Be extravagant',
  'Be less critical more often',
  'Breathe more deeply',
  'Bridges (build) ',
  'Bridges (burn)',
  'Cascades',
  'Change instrument roles',
  'Change nothing and continue with immaculate consistency',
  'Children speaking ',
  'Children singing',
  'Cluster analysis',
  'Consider different fading systems',
  'Consult other sources Promising ',
  'Consult other sources Unpromising',
  'Convert a melodic element into a rhythmic element',
  'Courage !',
  'Cut a vital connection',
  'Decorate, decorate',
  "Define an area 'safe' and use it as an anchor",
  'Destroy nothing',
  'Destroy the most important thing',
  'Discard an axiom',
  'Disciplined self-indulgence',
  'Disconnect from desire',
  'Discover the recipes you are using and abandon them',
  'Distorting time',
  'Do nothing for as long as possible',
  'Do something boring',
  'Do the washing up',
  'Do the words need changing?',
  'Do we need holes?',
  "Don't be afraid of things because they're easy to do",
  "Don't be frightened of cliches",
  "Don't be frightened to display yourtalents",
  "Don't break the silence",
  "Don't stress one thing more than another",
  'Emphasize differences',
  'Emphasize repetitions',
  'Emphasize the flaws',
  'Faced with a choice, do both',
  'Feed the recording back out of the medium',
  'Fill every beat with something',
  'Get your neck massaged',
  'From nothing to more than nothing',
  'Ghost echoes',
  'Give the game away',
  'Give way to your worst impulse',
  'Go outside. Shut the door',
  'Go slowly all the way round the circle',
  'Go to an extreme, move back to a more comfortable place',
  'Honor thy error as a hidden intention',
  'How would you have done it ?',
  'Humanize something free of error',
  'Idiot glee (?)',
  'Imagine the pieces as a set of disconnected events',
  'In total darkness, or in a very largeroom, very quietly',
  'Infinitesimal gradations',
  'Intentions - nobility of - humility of - credibility of',
  'Into the impossible',
  'Is it finished ?',
  'Is the intonation correct ?',
  'Is there something missing ?',
  'It is quite possible (after all)',
  'Just carry on',
  'Left channel, right channel, center channel',
  'Listen to the quiet voice',
  'Look at the order in which you do things',
  'Look closely at the most embarrassing details and amplify them',
  'Lost in useless territory',
  'Lowest common denominator',
  'Make a blank valuable by putting it in an exquisite frame',
  'Make a sudden, destructive unpredictable action; incorporate',
  'Make an exhaustive list of everything you might do and do the last thing on the list',
  'Mechanicalize something idiosyncratic',
  'Mute and continue',
  'Not building a wall but making a brick',
  'Once the search is in progress, something will be found',
  'Only a part, not the whole',
  'Only one element of each kind',
  'Overtly resist change',
  'Put in earplugs',
  'Question the heroic approach',
  'Reevaluation (a warm feeling) was revaluation',
  'Remember those quiet evenings',
  'Remember specifics and convert to ambiguities',
  'Remove ambiguities and convert to specifics',
  'Repetition is a form of change',
  'Retrace your steps',
  'Reverse',
  'Short circuit (example; a man eating peas with the idea that they will improve his virility shovels them straight into his lap)',
  'Simple subtraction',
  'Simply a matter of work',
  'Spectrum analysis',
  'State the problem in words as clearly as possible',
  'Take a break',
  'Take away the elements in order of apparent non-importance',
  'Tape your mouth',
  'The inconsistency principle',
  'The most important thing is the thing most easily forgotten',
  'The tape is now the music',
  'Think of the radio',
  'Tidy up',
  'Towards the insignificant',
  'Trust in the you of now',
  'Turn it upside down',
  'Twist the spine',
  "Use 'unqualified' people",
  'Use an old idea',
  'Use an unacceptable colour',
  'Use fewer notes',
  'Use filters',
  'Water',
  'What are the sections of? Imagine a caterpillar moving',
  'What are you really thinking about just now?',
  'What is the reality of the situation ?',
  'What mistakes did you make last time?',
  'What would your closest friend do ?',
  "What wouldn't you do?",
  'Work at a different speed',
  'Would anybody want it ?',
  'You are an engineer',
  'You can only make one dot at a time',
  "You don't have to be ashamed of using your own ideas"
]

const ObliqueStrategiesGarden = () => {
  // Generate 10x10 grid with 20 random strategies placed
  // Memoized so grid doesn't regenerate on every render
  const grid = useMemo(() => {
    const newGrid = Array(10)
      .fill(null)
      .map(() => Array(10).fill(''))

    // Place 20 random strategies in random positions
    for (let i = 0; i < 20; i++) {
      const x = Math.floor(Math.random() * 10)
      const y = Math.floor(Math.random() * 10)
      const strategyIndex = Math.floor(Math.random() * STRATEGIES.length)
      newGrid[y][x] = STRATEGIES[strategyIndex]
    }

    return newGrid
  }, []) // Empty deps - generate once on mount

  return (
    <div className="oblique-strategies-garden">
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <tbody>
          {grid.map((row, y) => (
            <tr key={y}>
              {row.map((strategy, x) => (
                <td
                  key={`${y}-${x}`}
                  style={{
                    border: '1px solid #ddd',
                    padding: '8px',
                    minHeight: '40px',
                    verticalAlign: 'top',
                    fontSize: '0.9em'
                  }}
                >
                  {strategy}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default ObliqueStrategiesGarden
