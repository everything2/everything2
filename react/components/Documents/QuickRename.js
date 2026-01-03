import React, { useState } from 'react'

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
    backgroundColor: '#f8f9fa',
    padding: '15px',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
    fontSize: '14px',
  },
  resultsSuccess: {
    padding: '15px',
    marginBottom: '20px',
    backgroundColor: '#d4edda',
    border: '1px solid #c3e6cb',
    borderRadius: '8px',
  },
  resultsError: {
    padding: '15px',
    marginBottom: '20px',
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: '8px',
  },
  resultsSummary: {
    margin: '0 0 10px 0',
    fontWeight: 'bold',
  },
  resultsList: {
    margin: 0,
    paddingLeft: '20px',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
  },
  th: {
    textAlign: 'left',
    padding: '10px 12px',
    backgroundColor: '#38495e',
    color: '#fff',
    fontWeight: 'bold',
    fontSize: '14px',
  },
  thNumber: {
    width: '40px',
    textAlign: 'center',
  },
  td: {
    padding: '4px 8px',
    borderBottom: '1px solid #eee',
  },
  tdNumber: {
    textAlign: 'center',
    color: '#999',
    fontSize: '12px',
  },
  input: {
    width: '100%',
    padding: '6px 10px',
    border: '1px solid #ddd',
    borderRadius: '4px',
    fontSize: '14px',
    boxSizing: 'border-box',
  },
  inputFilled: {
    width: '100%',
    padding: '6px 10px',
    border: '1px solid #007bff',
    borderRadius: '4px',
    fontSize: '14px',
    boxSizing: 'border-box',
    backgroundColor: '#f0f7ff',
  },
  arrow: {
    textAlign: 'center',
    color: '#666',
    fontSize: '18px',
    padding: '0 5px',
  },
  submitBtn: {
    padding: '10px 24px',
    backgroundColor: '#38495e',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
  },
  submitBtnDisabled: {
    padding: '10px 24px',
    backgroundColor: '#38495e',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'not-allowed',
    fontSize: '14px',
    fontWeight: 'bold',
    opacity: 0.6,
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  hint: {
    fontSize: '12px',
    color: '#666',
  },
}

/**
 * QuickRename - Bulk e2node rename tool for editors
 *
 * Allows retitling multiple e2nodes at once with automatic repair.
 */
const QuickRename = ({ data }) => {
  const maxItems = data?.quickRename?.maxItems || 10

  // Initialize empty rename pairs
  const [renames, setRenames] = useState(
    Array(maxItems).fill(null).map(() => ({ from: '', to: '' }))
  )
  const [results, setResults] = useState(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleChange = (index, field, value) => {
    const newRenames = [...renames]
    newRenames[index] = { ...newRenames[index], [field]: value }
    setRenames(newRenames)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setResults(null)

    // Filter out empty rows
    const nonEmptyRenames = renames.filter(r => r.from.trim() && r.to.trim())

    if (nonEmptyRenames.length === 0) {
      setResults({ error: 'No rename operations specified. Fill in at least one row.' })
      setIsSubmitting(false)
      return
    }

    try {
      const response = await fetch('/api/e2nodes/bulk-rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ renames: nonEmptyRenames })
      })

      const result = await response.json()
      setResults(result)

      // Clear successful renames
      if (result.success && result.results) {
        const newRenames = [...renames]
        result.results.forEach((r) => {
          if (r.status === 'renamed') {
            // Find and clear this rename from the form
            const idx = renames.findIndex(
              ren => ren.from.trim() === r.from && ren.to.trim() === r.to
            )
            if (idx !== -1) {
              newRenames[idx] = { from: '', to: '' }
            }
          }
        })
        setRenames(newRenames)
      }
    } catch (error) {
      setResults({ error: 'An error occurred: ' + error.message })
    } finally {
      setIsSubmitting(false)
    }
  }

  const getStatusColor = (status) => {
    switch (status) {
      case 'renamed': return '#28a745'
      case 'not_found': return '#dc3545'
      case 'target_exists': return '#dc3545'
      case 'no_change': return '#856404'
      default: return '#6c757d'
    }
  }

  const filledCount = renames.filter(r => r.from.trim() || r.to.trim()).length

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Quick Rename</h1>
      </div>

      <div style={styles.description}>
        <p style={{ margin: '0 0 10px 0' }}>
          <strong>Bulk rename e2nodes</strong> — Enter the current title on the left and the new title on the right.
          Each node will be renamed and automatically repaired.
        </p>
        <p style={{ margin: 0, fontSize: '13px', color: '#666' }}>
          Leave rows blank to skip them. Only filled rows will be processed.
        </p>
      </div>

      {results && (
        <div style={results.error ? styles.resultsError : styles.resultsSuccess}>
          {results.error ? (
            <p style={{ color: '#721c24', margin: 0 }}>{results.error}</p>
          ) : (
            <>
              <p style={styles.resultsSummary}>
                Results: {results.counts?.renamed || 0} renamed,{' '}
                {results.counts?.not_found || 0} not found,{' '}
                {results.counts?.target_exists || 0} target exists,{' '}
                {results.counts?.no_change || 0} no change
              </p>
              <ul style={styles.resultsList}>
                {results.results?.map((r, i) => (
                  <li key={i} style={{ color: getStatusColor(r.status), marginBottom: '4px' }}>
                    <strong>{r.from}</strong> → <strong>{r.to}</strong>: {r.message}
                    {r.repairSuccess === false && ' (repair failed)'}
                  </li>
                ))}
              </ul>
            </>
          )}
        </div>
      )}

      <form onSubmit={handleSubmit}>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={{ ...styles.th, ...styles.thNumber }}>#</th>
              <th style={styles.th}>Current Title</th>
              <th style={{ ...styles.th, width: '30px' }}></th>
              <th style={styles.th}>New Title</th>
            </tr>
          </thead>
          <tbody>
            {renames.map((rename, index) => {
              const isFilled = rename.from.trim() || rename.to.trim()
              return (
                <tr key={index} style={{ backgroundColor: index % 2 === 0 ? '#fff' : '#fafafa' }}>
                  <td style={{ ...styles.td, ...styles.tdNumber }}>{index + 1}</td>
                  <td style={styles.td}>
                    <input
                      type="text"
                      value={rename.from}
                      onChange={(e) => handleChange(index, 'from', e.target.value)}
                      style={isFilled ? styles.inputFilled : styles.input}
                      disabled={isSubmitting}
                      placeholder="e.g. Teh Quick Brown Fox"
                    />
                  </td>
                  <td style={styles.arrow}>→</td>
                  <td style={styles.td}>
                    <input
                      type="text"
                      value={rename.to}
                      onChange={(e) => handleChange(index, 'to', e.target.value)}
                      style={isFilled ? styles.inputFilled : styles.input}
                      disabled={isSubmitting}
                      placeholder="e.g. The Quick Brown Fox"
                    />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>

        <div style={styles.footer}>
          <span style={styles.hint}>
            {filledCount > 0 ? `${filledCount} row${filledCount === 1 ? '' : 's'} to process` : 'Fill in rows above'}
          </span>
          <button
            type="submit"
            disabled={isSubmitting}
            style={isSubmitting ? styles.submitBtnDisabled : styles.submitBtn}
          >
            {isSubmitting ? 'Processing...' : 'Rename All'}
          </button>
        </div>
      </form>
    </div>
  )
}

export default QuickRename
