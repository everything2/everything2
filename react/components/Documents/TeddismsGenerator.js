import React, { useState, useCallback } from 'react'

const NOUNS = [
  'NUN', 'NUN', 'NUN', 'NUN', 'NUN', 'CHRIST', 'POWERHOOKER', 'CUNT', 'PORN',
  'COCK', 'CRUNCH', 'POOP', 'JEW', 'FUCK', 'FUCK', 'FUCK', 'FUCK', 'FUCK',
  'FUCK', 'SHIT', 'SHIT', 'SHIT', 'SHIT', 'BRIT', 'FLANNEL', 'CRAP', 'TIT',
  'SLUT', 'PISS', 'DICK', 'ASS', 'PUBIC', 'SIDE', 'CHALLA', 'COMMA', 'BLING',
  'ASS', 'TURD', 'GOD'
]

const VERBS = [
  'SHITT', 'FUCK', 'GAGG', 'TAPP', 'SLAPP', 'BURN', 'PISS', 'LICK', 'CRAPP',
  'BLAST', 'MUNCH'
]

const PHRASES = ['UNRELENTING FUCKTARD']

const randomChoice = (arr) => arr[Math.floor(Math.random() * arr.length)]

const generateTeddism = () => {
  const pattern = Math.floor(Math.random() * 10)

  if (pattern === 5) {
    // NOUN + VERB + "ING " + NOUN
    return randomChoice(NOUNS) + randomChoice(VERBS) + 'ING ' + randomChoice(NOUNS)
  } else if (pattern === 4) {
    // NOUN + NOUN + VERB + "ER"
    return randomChoice(NOUNS) + randomChoice(NOUNS) + randomChoice(VERBS) + 'ER'
  } else if (pattern === 3) {
    // NOUN + VERB + "ING " + NOUN + VERB + "ER"
    return randomChoice(NOUNS) + randomChoice(VERBS) + 'ING ' + randomChoice(NOUNS) + randomChoice(VERBS) + 'ER'
  } else if (pattern === 2) {
    // Random phrase
    return randomChoice(PHRASES)
  } else {
    // Default: NOUN + VERB + "ING " + NOUN + VERB + "ER"
    return randomChoice(NOUNS) + randomChoice(VERBS) + 'ING ' + randomChoice(NOUNS) + randomChoice(VERBS) + 'ER'
  }
}

const TeddismsGenerator = () => {
  const [teddism, setTeddism] = useState(generateTeddism)

  const handleGenerate = useCallback(() => {
    setTeddism(generateTeddism())
  }, [])

  const containerStyle = {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: '60vh',
    padding: '20px',
    textAlign: 'center'
  }

  const teddismStyle = {
    fontSize: 'clamp(2rem, 8vw, 5rem)',
    fontWeight: 'bold',
    fontStyle: 'italic',
    color: '#111111',
    marginBottom: '40px',
    wordBreak: 'break-word',
    maxWidth: '100%'
  }

  const buttonStyle = {
    padding: '15px 30px',
    fontSize: '1.2rem',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer'
  }

  return (
    <div style={containerStyle}>
      <div style={teddismStyle}>
        {teddism}!
      </div>
      <button
        style={buttonStyle}
        onClick={handleGenerate}
        onMouseOver={(e) => e.target.style.backgroundColor = '#4060b0'}
        onMouseOut={(e) => e.target.style.backgroundColor = '#38495e'}
      >
        Generate Another
      </button>
    </div>
  )
}

export default TeddismsGenerator
