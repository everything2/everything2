import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '600px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  description: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
  },
  th: {
    textAlign: 'left',
    padding: '10px',
    backgroundColor: '#e9ecef',
    border: '1px solid #ddd',
    fontWeight: 'bold',
  },
  td: {
    padding: '10px',
    border: '1px solid #ddd',
  },
  input: {
    width: '100%',
    padding: '8px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    boxSizing: 'border-box',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#dc3545',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  },
  buttonDisabled: {
    padding: '10px 20px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'not-allowed',
    fontSize: '14px',
  },
  results: {
    marginTop: '20px',
  },
  resultItem: {
    padding: '10px',
    marginBottom: '8px',
    borderRadius: '4px',
  },
  success: {
    backgroundColor: '#d4edda',
    color: '#155724',
    border: '1px solid #c3e6cb',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
  },
}

const CostumeRemover = ({ data }) => {
  const [usernames, setUsernames] = useState(['', '', '', '', ''])
  const [processing, setProcessing] = useState(false)
  const [results, setResults] = useState([])

  const handleUsernameChange = useCallback((index, value) => {
    setUsernames(prev => {
      const updated = [...prev]
      updated[index] = value
      return updated
    })
  }, [])

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()

    const usersToProcess = usernames.filter(u => u.trim() !== '')
    if (usersToProcess.length === 0) {
      return
    }

    setProcessing(true)
    setResults([])

    const newResults = []

    for (const username of usersToProcess) {
      try {
        const response = await fetch('/api/costumes/remove', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ username: username.trim() }),
        })

        const result = await response.json()

        if (result.success) {
          newResults.push({
            type: 'success',
            message: result.message,
          })
        } else {
          newResults.push({
            type: 'error',
            message: result.error || `Failed to remove costume from ${username}`,
          })
        }
      } catch (err) {
        newResults.push({
          type: 'error',
          message: `Failed to connect to server for ${username}`,
        })
      }
    }

    setResults(newResults)
    setProcessing(false)

    // Clear the input fields on success
    if (newResults.some(r => r.type === 'success')) {
      setUsernames(['', '', '', '', ''])
    }
  }, [usernames])

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Costume Remover</h1>
      </div>

      <div style={styles.description}>
        <p>
          This tool deletes the costume variable for selected users. Use it to remove
          abusively or inappropriately named costumes.
        </p>
        <p>
          Users whose costumes are removed will receive a private message from Klaproth
          informing them of the removal.
        </p>
      </div>

      <form onSubmit={handleSubmit}>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Undress these users</th>
            </tr>
          </thead>
          <tbody>
            {usernames.map((username, index) => (
              <tr key={index}>
                <td style={styles.td}>
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => handleUsernameChange(index, e.target.value)}
                    style={styles.input}
                    placeholder="Enter username"
                    disabled={processing}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <button
          type="submit"
          style={processing ? styles.buttonDisabled : styles.button}
          disabled={processing}
        >
          {processing ? 'Processing...' : 'Remove Costumes'}
        </button>
      </form>

      {results.length > 0 && (
        <div style={styles.results}>
          {results.map((result, index) => (
            <div
              key={index}
              style={{
                ...styles.resultItem,
                ...(result.type === 'success' ? styles.success : styles.error),
              }}
            >
              {result.message}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default CostumeRemover
