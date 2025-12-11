import React from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * EverythingIChing - I-Ching hexagram divination tool
 *
 * Generates primary and secondary hexagrams using the coin method.
 * Displays hexagrams side-by-side with their corresponding writeup text.
 */
const EverythingIChing = ({ data }) => {
  const { error, primary, secondary } = data

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  if (!primary || !secondary) {
    return (
      <div style={styles.container}>
        <p>Loading divination...</p>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <table style={styles.mainTable}>
        <thead>
          <tr>
            <th style={styles.th}>Primary Hexagram</th>
            <th style={styles.th}>Secondary Hexagram</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td style={styles.td}>
              <div style={styles.centered}>
                <LinkNode nodeId={primary.node_id} title={primary.title} />
              </div>
            </td>
            <td style={styles.td}>
              <div style={styles.centered}>
                <LinkNode nodeId={secondary.node_id} title={secondary.title} />
              </div>
            </td>
          </tr>
          <tr>
            <td style={styles.hexagramCell} colSpan={2}>
              <table style={styles.hexagramContainer}>
                <tbody>
                  <tr>
                    <td style={styles.hexagramTd}>
                      <Hexagram pattern={primary.pattern} />
                    </td>
                    <td style={styles.hexagramTd}>
                      <Hexagram pattern={secondary.pattern} />
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
          <tr>
            <td style={styles.textTd}>
              <ParseLinks content={primary.text} />
            </td>
            <td style={styles.textTd}>
              <ParseLinks content={secondary.text} />
            </td>
          </tr>
        </tbody>
      </table>

      <div style={styles.footer}>
        <p style={styles.footerText}>
          <em>
            The <LinkNode nodeId={window.e2?.node_id} title="Everything I Ching" /> is brought to
            you by <LinkNode title="The Gilded Frame" /> and <LinkNode title="nate" />
          </em>
        </p>
        <p style={styles.reDivine}>
          <a href={`?node_id=${window.e2?.node_id || ''}`} style={styles.reDivineLink}>
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
    <table style={styles.hexTable}>
      <tbody>
        {lines.map((letter, index) => (
          <tr key={index}>
            <td style={styles.hexTd}>
              <img
                src={
                  letter.toUpperCase() === 'B'
                    ? `${assetsBase}/static/broke.gif`
                    : `${assetsBase}/static/full.gif`
                }
                width={128}
                height={14}
                alt={letter === 'B' ? 'Broken line' : 'Full line'}
                style={styles.hexImage}
              />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  mainTable: {
    width: '100%',
    borderCollapse: 'collapse',
    border: '1px solid #d3d3d3'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'center',
    border: '1px solid #38495e',
    width: '50%'
  },
  td: {
    border: '1px solid #d3d3d3',
    padding: '12px',
    verticalAlign: 'top',
    width: '50%'
  },
  centered: {
    textAlign: 'center'
  },
  hexagramCell: {
    backgroundColor: '#000000',
    border: '1px solid #000000',
    padding: 0
  },
  hexagramContainer: {
    width: '100%',
    backgroundColor: '#000000',
    borderCollapse: 'collapse',
    padding: 0,
    border: 'none'
  },
  hexagramTd: {
    textAlign: 'center',
    width: '50%',
    padding: '10px',
    backgroundColor: '#000000',
    border: 'none'
  },
  textTd: {
    border: '1px solid #d3d3d3',
    padding: '12px',
    verticalAlign: 'top',
    width: '50%'
  },
  hexTable: {
    width: '100%',
    backgroundColor: '#ffffff',
    borderCollapse: 'collapse',
    border: 'none'
  },
  hexTd: {
    textAlign: 'center',
    padding: '3px',
    border: 'none'
  },
  hexImage: {
    display: 'block',
    margin: '0 auto'
  },
  footer: {
    marginTop: '20px'
  },
  footerText: {
    textAlign: 'right',
    fontStyle: 'italic',
    marginBottom: '10px'
  },
  reDivine: {
    textAlign: 'center',
    margin: '20px 0'
  },
  reDivineLink: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none'
  }
}

export default EverythingIChing
