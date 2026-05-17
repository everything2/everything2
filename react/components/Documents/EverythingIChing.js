import React from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * EverythingIChing - I-Ching hexagram divination tool
 * Styles in CSS: .e2-iching__*
 *
 * Generates primary and secondary hexagrams using the coin method.
 * Displays hexagrams side-by-side with their corresponding writeup text.
 */
const EverythingIChing = ({ data }) => {
  const { error, primary, secondary } = data

  if (error) {
    return (
      <div className="e2-iching">
        <div className="e2-iching__error">{error}</div>
      </div>
    )
  }

  if (!primary || !secondary) {
    return (
      <div className="e2-iching">
        <p>Loading divination...</p>
      </div>
    )
  }

  return (
    <div className="e2-iching">
      <table className="e2-iching__table">
        <thead>
          <tr>
            <th className="e2-iching__th">Primary Hexagram</th>
            <th className="e2-iching__th">Secondary Hexagram</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td className="e2-iching__td">
              <div className="e2-iching__centered">
                <LinkNode nodeId={primary.node_id} title={primary.title} />
              </div>
            </td>
            <td className="e2-iching__td">
              <div className="e2-iching__centered">
                <LinkNode nodeId={secondary.node_id} title={secondary.title} />
              </div>
            </td>
          </tr>
          <tr>
            <td className="e2-iching__hexagram-cell" colSpan={2}>
              <table className="e2-iching__hexagram-container">
                <tbody>
                  <tr>
                    <td className="e2-iching__hexagram-td">
                      <Hexagram pattern={primary.pattern} />
                    </td>
                    <td className="e2-iching__hexagram-td">
                      <Hexagram pattern={secondary.pattern} />
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
          <tr>
            <td className="e2-iching__text-td">
              <ParseLinks content={primary.text} />
            </td>
            <td className="e2-iching__text-td">
              <ParseLinks content={secondary.text} />
            </td>
          </tr>
        </tbody>
      </table>

      <div className="e2-iching__footer">
        <p className="e2-iching__footer-text">
          <em>
            The <LinkNode nodeId={window.e2?.node_id} title="Everything I Ching" /> is brought to
            you by <LinkNode title="The Gilded Frame" /> and <LinkNode title="nate" />
          </em>
        </p>
        <p className="e2-iching__re-divine">
          <a href={`?node_id=${window.e2?.node_id || ''}`} className="e2-iching__re-divine-link">
            re-divine
          </a>
        </p>
      </div>
    </div>
  )
}

/**
 * Hexagram component - renders I-Ching hexagram visualization
 * @param {string} pattern - 6-character string of 'B' (broken) or 'F' (full) lines
 */
const Hexagram = ({ pattern }) => {
  // Reverse the pattern to draw from bottom to top
  const lines = pattern.split('').reverse()
  const assetsBase = window.e2?.assets_location || ''

  return (
    <table className="e2-iching__hex-table">
      <tbody>
        {lines.map((letter, index) => (
          <tr key={index}>
            <td className="e2-iching__hex-td">
              <img
                src={
                  letter.toUpperCase() === 'B'
                    ? `${assetsBase}/static/broke.gif`
                    : `${assetsBase}/static/full.gif`
                }
                width={128}
                height={14}
                alt={letter === 'B' ? 'Broken line' : 'Full line'}
                className="e2-iching__hex-image"
              />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

export default EverythingIChing
