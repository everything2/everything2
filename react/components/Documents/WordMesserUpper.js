import React, { useState } from 'react'

/**
 * WordMesserUpper - Client-side word shuffler
 * Pure JavaScript implementation with Fisher-Yates shuffle algorithm
 * No server-side processing required
 */
const WordMesserUpper = () => {
  const [text, setText] = useState('')
  const [numBreaks, setNumBreaks] = useState('0')
  const [messedText, setMessedText] = useState('')

  // Fisher-Yates shuffle algorithm (in-place shuffle)
  const fisherYatesShuffle = (array) => {
    const shuffled = [...array] // Create a copy
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
    }
    return shuffled
  }

  const handleMessUp = (e) => {
    e.preventDefault()

    if (!text.trim()) {
      setMessedText('')
      return
    }

    // Split text into words
    let words = text.split(' ')

    // Insert line breaks at random positions
    const breaks = parseInt(numBreaks) || 0
    for (let i = 0; i < breaks; i++) {
      const randomIndex = Math.floor(Math.random() * words.length)
      words[randomIndex] = words[randomIndex] + '\n'
    }

    // Shuffle words using Fisher-Yates algorithm
    words = fisherYatesShuffle(words)

    // Join back together
    const result = words.join(' ')
    setText(result)
    setMessedText(result)
  }

  // Format messed text for display (show line breaks as <br> tags)
  const formatMessedText = (text) => {
    if (!text) return null

    return text.split('\n').map((line, index) => (
      <React.Fragment key={index}>
        {line}
        {index < text.split('\n').length - 1 && <><br />&lt;br&gt;<br /></>}
      </React.Fragment>
    ))
  }

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        Type in something you'd like to see messed up:
      </p>

      <form onSubmit={handleMessUp} style={styles.form}>
        <div style={styles.breaksControl}>
          <label style={styles.breaksLabel}>
            insert{' '}
            <input
              type="number"
              value={numBreaks}
              onChange={(e) => setNumBreaks(e.target.value)}
              style={styles.breaksInput}
              min="0"
              max="99"
            />
            {' '}line breaks
          </label>
        </div>

        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={10}
          cols={60}
          style={styles.textarea}
          placeholder="Enter text here..."
        />

        <button type="submit" style={styles.button}>
          Mess it up!
        </button>
      </form>

      {messedText && (
        <div style={styles.output}>
          <h3 style={styles.outputHeading}>Messed up text:</h3>
          <div style={styles.outputText}>
            {formatMessedText(messedText)}
          </div>
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  intro: {
    marginBottom: '20px',
    fontSize: '14px',
    color: '#38495e'
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '12px'
  },
  breaksControl: {
    marginBottom: '8px'
  },
  breaksLabel: {
    fontSize: '13px',
    color: '#38495e'
  },
  breaksInput: {
    width: '50px',
    padding: '4px 8px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '13px',
    textAlign: 'center'
  },
  textarea: {
    width: '100%',
    padding: '12px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '13px',
    fontFamily: 'monospace',
    resize: 'vertical',
    boxSizing: 'border-box'
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#4060b0',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: 'bold',
    cursor: 'pointer',
    alignSelf: 'flex-start'
  },
  output: {
    marginTop: '30px',
    padding: '20px',
    backgroundColor: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  outputHeading: {
    fontSize: '16px',
    fontWeight: 'bold',
    marginTop: 0,
    marginBottom: '15px',
    color: '#38495e'
  },
  outputText: {
    fontSize: '13px',
    lineHeight: '1.6',
    fontFamily: 'monospace',
    color: '#111',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-word'
  }
}

export default WordMesserUpper
