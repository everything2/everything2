import React, { useState } from 'react'
import ParseLinks from '../ParseLinks'

/**
 * RandomText - Reusable component for random text generators
 *
 * Used by:
 * - fezisms_generator - Random fez quotes in 2 columns
 * - piercisms_generator - Single random pierce quote
 *
 * Features:
 * - Randomly selects one item from each array in data.wit
 * - Parses E2 bracket links in selected text
 * - Supports multi-column layouts
 * - Large, bold, centered display
 * - Generates new quotes without page reload
 */

const RandomText = ({ data }) => {
  const { type, wit, title, description } = data

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
