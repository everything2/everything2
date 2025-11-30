import React, { useState, useCallback } from 'react'

/**
 * BuffaloGenerator - Generates random buffalo-style sentences
 *
 * Implements both regular buffalo generator and haiku mode.
 * Based on the linguistic curiosity that "Buffalo buffalo Buffalo buffalo
 * buffalo buffalo Buffalo buffalo" is a grammatically correct sentence.
 *
 * Features:
 * - Random sentence generation with verb-nouns (buffalo, police, bream, etc.)
 * - Optional punctuation for variety
 * - Haiku mode with 5-7-5 syllable structure
 * - "Only buffalo" mode for purists
 * - Client-side generation (no API needed)
 */

const BuffaloGenerator = ({ data }) => {
  const { type, only_buffalo: initialOnlyBuffalo } = data

  const isHaiku = type === 'buffalo_haiku_generator'

  // State for "only buffalo" mode - can be toggled client-side
  const [onlyBuffalo, setOnlyBuffalo] = useState(initialOnlyBuffalo)

  // Word lists with syllable counts for haiku mode
  // Format: [word, syllables]
  const verbNounsWithSyllables = [
    ['Buffalo', 3],
    ['buffalo', 3],
    ['police', 2],
    ['bream', 1],
    ['perch', 1],
    ['char', 1],
    ['people', 2],
    ['dice', 1],
    ['cod', 1],
    ['smelt', 1],
    ['pants', 1]
  ]

  // For regular mode (no syllable counting needed)
  const verbNouns = onlyBuffalo
    ? ['buffalo']
    : verbNounsWithSyllables.map(([word]) => word)

  // For haiku mode
  const haikuWords = onlyBuffalo
    ? [['buffalo', 3]]
    : verbNounsWithSyllables

  const intermediatePunctuation = [',', ';', ',', ':', '...']
  const finalPunctuation = ['.', '!', '?']

  // Generate a regular buffalo sentence/paragraph
  const generateRegular = useCallback(() => {
    let result = ''

    // Generate 1-3 sentences
    while (true) {
      let sentence = ''

      // Build a sentence with random words
      while (true) {
        const word = verbNouns[Math.floor(Math.random() * verbNouns.length)]
        sentence += word

        // 10% chance to end sentence
        if (Math.random() < 0.1) break

        // 25% chance of intermediate punctuation
        if (Math.random() < 0.25) {
          sentence += intermediatePunctuation[Math.floor(Math.random() * intermediatePunctuation.length)]
        }
        sentence += ' '
      }

      // Capitalize first letter and add final punctuation
      sentence = sentence.charAt(0).toUpperCase() + sentence.slice(1)
      sentence += finalPunctuation[Math.floor(Math.random() * finalPunctuation.length)] + ' '
      result += sentence

      // 40% chance to stop adding sentences
      if (Math.random() < 0.4) break
    }

    return result.trim()
  }, [verbNouns])

  // Generate a buffalo haiku (5-7-5 syllables)
  // For "only buffalo" mode, we approximate since 3 doesn't divide evenly into 5 or 7
  const generateHaiku = useCallback(() => {
    const lineTargets = [5, 7, 5]
    const lines = []

    // Get words that could fit in remaining space
    const getValidWords = (remaining) => {
      return haikuWords.filter(([, s]) => s <= remaining)
    }

    for (const targetSyllables of lineTargets) {
      let line = ''
      let syllables = 0
      let attempts = 0
      const maxAttempts = 100 // Prevent infinite loop

      while (syllables < targetSyllables && attempts < maxAttempts) {
        attempts++
        const remaining = targetSyllables - syllables
        const validWords = getValidWords(remaining)

        // If no words fit exactly, just pick any word (allow slight overage)
        const wordsToChooseFrom = validWords.length > 0 ? validWords : haikuWords

        const picked = wordsToChooseFrom[Math.floor(Math.random() * wordsToChooseFrom.length)]
        const [word, wordSyllables] = picked

        syllables += wordSyllables
        line += word

        // Small chance of punctuation (less than regular mode)
        if (Math.random() < 0.1 && syllables < targetSyllables) {
          line += intermediatePunctuation[Math.floor(Math.random() * intermediatePunctuation.length)]
        }

        if (syllables < targetSyllables) {
          line += ' '
        }
      }

      lines.push(line)
    }

    // Capitalize first letter of haiku
    lines[0] = lines[0].charAt(0).toUpperCase() + lines[0].slice(1)

    return lines
  }, [haikuWords])

  // State for generated content
  const [content, setContent] = useState(() =>
    isHaiku ? generateHaiku() : generateRegular()
  )

  const handleGenerate = () => {
    setContent(isHaiku ? generateHaiku() : generateRegular())
  }

  const containerStyle = {
    padding: '20px',
    maxWidth: '700px'
  }

  const outputStyle = {
    fontSize: isHaiku ? '1.3em' : '1.2em',
    lineHeight: '1.6',
    margin: '30px 0',
    padding: '20px',
    backgroundColor: '#f8f9f9',
    borderRadius: '5px',
    textAlign: isHaiku ? 'center' : 'left'
  }

  const buttonStyle = {
    padding: '10px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
    marginRight: '10px'
  }

  const linkStyle = {
    color: '#4060b0',
    textDecoration: 'none',
    marginLeft: '15px'
  }

  return (
    <div style={containerStyle}>
      <div style={outputStyle}>
        {isHaiku ? (
          // Haiku: three lines, centered
          <div>
            {content.map((line, i) => (
              <div key={i}>{line}</div>
            ))}
          </div>
        ) : (
          // Regular: paragraph
          <p style={{ margin: 0 }}>{content}</p>
        )}
      </div>

      <div style={{ marginTop: '30px' }}>
        <button onClick={handleGenerate} style={buttonStyle}>
          {isHaiku ? 'Furthermore!' : 'MOAR'}
        </button>

        {!onlyBuffalo && (
          <button
            onClick={() => {
              setOnlyBuffalo(true)
              // Generate new content with only buffalo - need to do it manually
              // since state update is async
              if (isHaiku) {
                // For buffalo-only haiku, just use 2 words per line (6 syllables each)
                // since 3 doesn't divide evenly into 5 or 7
                const lines = [
                  'Buffalo buffalo',
                  'buffalo buffalo buffalo',
                  'buffalo buffalo'
                ]
                setContent(lines)
              } else {
                let result = ''
                while (true) {
                  let sentence = ''
                  while (true) {
                    sentence += 'buffalo'
                    if (Math.random() < 0.1) break
                    if (Math.random() < 0.25) {
                      sentence += intermediatePunctuation[Math.floor(Math.random() * intermediatePunctuation.length)]
                    }
                    sentence += ' '
                  }
                  sentence = sentence.charAt(0).toUpperCase() + sentence.slice(1)
                  sentence += finalPunctuation[Math.floor(Math.random() * finalPunctuation.length)] + ' '
                  result += sentence
                  if (Math.random() < 0.4) break
                }
                setContent(result.trim())
              }
            }}
            style={buttonStyle}
          >
            Only buffalo
          </button>
        )}

        {isHaiku ? (
          <button
            onClick={() => { window.location.href = '/title/Buffalo+Generator' }}
            style={buttonStyle}
          >
            More buffalo, less haiku
          </button>
        ) : (
          <button
            onClick={() => { window.location.href = '/title/Buffalo+Haiku+Generator' }}
            style={buttonStyle}
          >
            In haiku form
          </button>
        )}
      </div>

      <div style={{ marginTop: '30px', textAlign: 'center' }}>
        <a
          href="/title/Buffalo+buffalo+Buffalo+buffalo+buffalo+buffalo+Buffalo+buffalo"
          style={linkStyle}
        >
          {isHaiku ? 'Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo' : '...what?'}
        </a>
      </div>
    </div>
  )
}

export default BuffaloGenerator
