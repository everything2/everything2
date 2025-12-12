import React, { useState } from 'react'

/**
 * TheTokenator - Admin tool to give tokens to users.
 * Tokens can be used to reset the chatterbox topic.
 */
const TheTokenator = ({ data }) => {
  const { access_denied, results: initialResults } = data

  const [users, setUsers] = useState(['', '', '', '', ''])
  const [results] = useState(initialResults || [])

  if (access_denied) {
    return (
      <div style={styles.container}>
        <h2 style={styles.title}>The Tokenator</h2>
        <div style={styles.errorBox}>
          <p>Access denied. Admins only.</p>
        </div>
      </div>
    )
  }

  const handleUserChange = (index, value) => {
    const newUsers = [...users]
    newUsers[index] = value
    setUsers(newUsers)
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    // Submit form via regular POST (let the server handle it)
    const form = e.target
    form.submit()
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.title}>The Tokenator</h2>

      {results.length > 0 && (
        <div style={styles.resultsBox}>
          {results.map((result, idx) => (
            <p
              key={idx}
              style={result.success ? styles.resultSuccess : styles.resultError}
            >
              {result.message}
            </p>
          ))}
        </div>
      )}

      <form method="POST" onSubmit={handleSubmit}>
        <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />
        <table style={styles.table}>
          <tbody>
            <tr>
              <th style={styles.th}>Tokenate these users</th>
            </tr>
            {users.map((user, idx) => (
              <tr key={idx}>
                <td style={styles.td}>
                  <input
                    type="text"
                    name={`tokenateUser${idx}`}
                    value={user}
                    onChange={(e) => handleUserChange(idx, e.target.value)}
                    style={styles.input}
                    placeholder="Username"
                  />
                </td>
              </tr>
            ))}
            <tr>
              <td style={{ ...styles.td, textAlign: 'center' }}>
                <button type="submit" style={styles.button}>
                  Give Tokens
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </form>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  title: {
    fontSize: '18px',
    fontWeight: 'bold',
    margin: '0 0 15px 0',
    color: '#38495e'
  },
  table: {
    borderCollapse: 'collapse',
    border: '1px solid #d3d3d3'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left'
  },
  td: {
    padding: '8px',
    borderBottom: '1px solid #e0e0e0'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '250px'
  },
  button: {
    padding: '8px 20px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  resultsBox: {
    backgroundColor: '#f8f9f9',
    padding: '10px',
    borderRadius: '4px',
    marginBottom: '15px',
    border: '1px solid #d3d3d3'
  },
  resultSuccess: {
    color: '#2e7d32',
    margin: '5px 0'
  },
  resultError: {
    color: '#c62828',
    margin: '5px 0'
  },
  errorBox: {
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    padding: '15px',
    color: '#c62828'
  }
}

export default TheTokenator
