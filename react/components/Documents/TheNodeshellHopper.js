import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '800px',
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
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  featureList: {
    marginBottom: '20px',
    paddingLeft: '20px',
  },
  form: {
    marginBottom: '20px',
  },
  textarea: {
    width: '100%',
    minHeight: '300px',
    padding: '10px',
    fontFamily: 'monospace',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    marginBottom: '15px',
    resize: 'vertical',
  },
  button: {
    padding: '12px 24px',
    backgroundColor: '#c00',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '16px',
    fontWeight: 'bold',
  },
  buttonDisabled: {
    backgroundColor: '#999',
    cursor: 'not-allowed',
  },
  results: {
    marginTop: '20px',
  },
  resultItem: {
    padding: '8px 12px',
    marginBottom: '4px',
    borderRadius: '4px',
    fontFamily: 'monospace',
    fontSize: '13px',
  },
  deleted: {
    backgroundColor: '#d4edda',
    color: '#155724',
  },
  notFound: {
    backgroundColor: '#fff3cd',
    color: '#856404',
  },
  notEmpty: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
  },
  hasFirmlink: {
    backgroundColor: '#cce5ff',
    color: '#004085',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
  },
  summary: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '4px',
    marginBottom: '20px',
  },
  summaryTitle: {
    margin: '0 0 10px 0',
    fontSize: '1.1rem',
  },
  warning: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    marginBottom: '20px',
  },
}

const TheNodeshellHopper = () => {
  const [nodeshells, setNodeshells] = useState('')
  const [loading, setLoading] = useState(false)
  const [results, setResults] = useState(null)
  const [error, setError] = useState(null)

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setResults(null)

    // Parse input - split by newlines, clean up
    const titles = nodeshells
      .split(/\n/)
      .map(line => line.trim())
      .filter(line => line.length > 0)

    if (titles.length === 0) {
      setError('Please enter at least one nodeshell title')
      setLoading(false)
      return
    }

    try {
      const response = await fetch('/api/nodeshells/delete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ nodeshells: titles }),
      })

      const data = await response.json()

      if (data.success) {
        setResults(data)
        // Clear the textarea after successful processing
        setNodeshells('')
      } else {
        setError(data.error || 'An error occurred')
      }
    } catch (err) {
      setError('Failed to connect to the server')
    } finally {
      setLoading(false)
    }
  }, [nodeshells])

  const getResultStyle = (status) => {
    switch (status) {
      case 'deleted': return { ...styles.resultItem, ...styles.deleted }
      case 'not_found': return { ...styles.resultItem, ...styles.notFound }
      case 'not_empty': return { ...styles.resultItem, ...styles.notEmpty }
      case 'has_firmlink': return { ...styles.resultItem, ...styles.hasFirmlink }
      default: return { ...styles.resultItem, ...styles.error }
    }
  }

  const getStatusLabel = (status) => {
    switch (status) {
      case 'deleted': return 'DELETED'
      case 'not_found': return 'NOT FOUND'
      case 'not_empty': return 'HAS WRITEUPS'
      case 'has_firmlink': return 'HAS FIRMLINK'
      default: return 'ERROR'
    }
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>The Nodeshell Hopper</h1>
      </div>

      <div style={styles.description}>
        <p>A smarter nodeshell deletion implementation.</p>
        <p>
          Copy and paste from the nodeshells marked for destruction lists.
          Enter one nodeshell title per line. <strong>DO NOT</strong> separate them by pipes.
        </p>
        <p><strong>Note:</strong> This operation may take some time for large lists.</p>
      </div>

      <ul style={styles.featureList}>
        <li>Checks to see if it's an E2node</li>
        <li>Checks to see whether it is empty</li>
        <li>Checks for firmlinks</li>
        <li>Deletes the nodeshell if all checks pass</li>
      </ul>

      <div style={styles.warning}>
        <strong>Warning:</strong> Deleted nodeshells cannot be recovered. Make sure you review the list carefully before proceeding.
      </div>

      <form onSubmit={handleSubmit} style={styles.form}>
        <textarea
          value={nodeshells}
          onChange={(e) => setNodeshells(e.target.value)}
          style={styles.textarea}
          placeholder="Enter nodeshell titles, one per line..."
          disabled={loading}
        />
        <button
          type="submit"
          style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
          disabled={loading || !nodeshells.trim()}
        >
          {loading ? 'Processing...' : 'Whack em all!'}
        </button>
      </form>

      {error && (
        <div style={{ ...styles.resultItem, ...styles.error }}>
          {error}
        </div>
      )}

      {results && (
        <div style={styles.results}>
          <div style={styles.summary}>
            <h3 style={styles.summaryTitle}>Results Summary</h3>
            <ul style={{ margin: 0, paddingLeft: '20px' }}>
              {results.counts.deleted > 0 && (
                <li><strong>{results.counts.deleted}</strong> nodeshell{results.counts.deleted !== 1 ? 's' : ''} deleted</li>
              )}
              {results.counts.not_found > 0 && (
                <li><strong>{results.counts.not_found}</strong> not found</li>
              )}
              {results.counts.not_empty > 0 && (
                <li><strong>{results.counts.not_empty}</strong> had writeups (not deleted)</li>
              )}
              {results.counts.has_firmlink > 0 && (
                <li><strong>{results.counts.has_firmlink}</strong> had firmlinks (not deleted)</li>
              )}
              {results.counts.error > 0 && (
                <li><strong>{results.counts.error}</strong> failed with errors</li>
              )}
            </ul>
          </div>

          <h3>Detailed Results</h3>
          {results.results.map((result, index) => (
            <div key={index} style={getResultStyle(result.status)}>
              <strong>{result.title}</strong> - [{getStatusLabel(result.status)}] {result.message}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default TheNodeshellHopper
