import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Websterbless - Tool for rewarding users who suggest corrections to Webster 1913
 *
 * Fixed blessing amount: 3 GP
 * Sends automated thank-you message from Webster 1913
 */
const Websterbless = ({ data }) => {
  const { error, msg_count, webster_id, results: initialResults = [], prefill_username = '' } = data

  const [rows, setRows] = useState(
    Array(5)
      .fill(null)
      .map((_, index) => ({
        username: index === 0 ? prefill_username : '',
        writeup: ''
      }))
  )
  const [results, setResults] = useState(initialResults)
  const [loading, setLoading] = useState(false)

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const updateRow = (index, field, value) => {
    const newRows = [...rows]
    newRows[index] = { ...newRows[index], [field]: value }
    setRows(newRows)
  }

  const handleSubmit = (e) => {
    // Let form submit naturally - page will reload with results
  }

  return (
    <div style={styles.container}>
      <div style={styles.description}>
        <p>A simple tool used to reward users who suggest writeup corrections to Webster 1913.</p>

        <div style={styles.noteBox}>
          <p>
            <strong>Users are blessed with 3 GP</strong> and receive an automated thank-you note
            from Webster 1913:
          </p>
          <blockquote style={styles.blockquote}>
            <em>
              <LinkNode nodeId={webster_id} title="Webster 1913" /> says re [Writeup name]: Thank
              you! My servants have attended to any errors.
            </em>
          </blockquote>
          <p style={styles.noteText}>
            Writeup name is optional (this parameter is pure text, it is not checked in any way).
          </p>
        </div>

        {msg_count > 0 && (
          <p>
            Webster 1913 has{' '}
            <a href={`?node_id=${webster_id}&node=Message+Inbox&spy_user=Webster+1913`}>
              {msg_count}
            </a>{' '}
            messages total
          </p>
        )}
      </div>

      <form method="post" onSubmit={handleSubmit}>
        <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />

        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Thank these users</th>
              <th style={styles.th}>Writeup name</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={index}>
                <td style={styles.td}>
                  <input
                    type="text"
                    name={`webbyblessUser${index}`}
                    value={row.username}
                    onChange={(e) => updateRow(index, 'username', e.target.value)}
                    style={styles.input}
                    className="userComplete"
                  />
                </td>
                <td style={styles.td}>
                  <input
                    type="text"
                    name={`webbyblessNode${index}`}
                    value={row.writeup}
                    onChange={(e) => updateRow(index, 'writeup', e.target.value)}
                    style={styles.input}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <button type="submit" style={styles.button}>
          Websterbless
        </button>
      </form>

      {results.length > 0 && (
        <div style={styles.results}>
          <h4 style={styles.resultsTitle}>Results:</h4>
          {results.map((result, index) => (
            <div key={index} style={result.success ? styles.success : styles.error}>
              {result.error ? (
                <span>✗ {result.error}</span>
              ) : (
                <span>✓ {result.message}</span>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    maxWidth: '700px',
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
  description: {
    marginBottom: '20px'
  },
  noteBox: {
    padding: '15px',
    backgroundColor: '#f8f9f9',
    borderLeft: '3px solid #507898',
    borderRadius: '3px',
    marginTop: '15px',
    marginBottom: '15px'
  },
  noteText: {
    fontSize: '12px',
    color: '#507898',
    marginTop: '10px',
    marginBottom: '0'
  },
  blockquote: {
    margin: '10px 0',
    padding: '10px 20px',
    borderLeft: '3px solid #38495e',
    backgroundColor: '#ffffff',
    fontStyle: 'italic'
  },
  table: {
    borderCollapse: 'collapse',
    width: '100%',
    marginBottom: '20px',
    border: '1px solid #38495e'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left',
    border: '1px solid #38495e'
  },
  td: {
    border: '1px solid #d3d3d3',
    padding: '8px'
  },
  input: {
    width: '100%',
    padding: '8px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    boxSizing: 'border-box'
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  results: {
    marginTop: '20px',
    padding: '15px',
    backgroundColor: '#f8f9f9',
    borderRadius: '5px'
  },
  resultsTitle: {
    marginTop: 0,
    color: '#38495e'
  },
  success: {
    color: '#228b22',
    marginBottom: '5px'
  },
  error: {
    color: '#8b0000',
    marginBottom: '5px'
  }
}

export default Websterbless
