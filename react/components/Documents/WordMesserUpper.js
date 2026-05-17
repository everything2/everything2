import React, { useState } from 'react'

/**
 * WordMesserUpper - Client-side word shuffler
 * Styles in CSS: .word-messer-upper__*
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
    <div className="word-messer-upper">
      <p className="word-messer-upper__intro">
        Type in something you'd like to see messed up:
      </p>

      <form onSubmit={handleMessUp} className="word-messer-upper__form">
        <div className="word-messer-upper__breaks-control">
          <label className="word-messer-upper__breaks-label">
            insert{' '}
            <input
              type="number"
              value={numBreaks}
              onChange={(e) => setNumBreaks(e.target.value)}
              className="word-messer-upper__breaks-input"
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
          className="word-messer-upper__textarea"
          placeholder="Enter text here..."
        />

        <button type="submit" className="word-messer-upper__button">
          Mess it up!
        </button>
      </form>

      {messedText && (
        <div className="word-messer-upper__output">
          <h3 className="word-messer-upper__output-heading">Messed up text:</h3>
          <div className="word-messer-upper__output-text">
            {formatMessedText(messedText)}
          </div>
        </div>
      )}
    </div>
  )
}

export default WordMesserUpper
