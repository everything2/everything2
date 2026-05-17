import React, { useState, useCallback } from 'react'

/**
 * TheNodeshellHopper - Bulk nodeshell deletion tool
 * Styles in CSS: .nodeshell-hopper__*
 */
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

  const getResultClassName = (status) => {
    const base = 'nodeshell-hopper__result-item'
    switch (status) {
      case 'deleted': return `${base} ${base}--deleted`
      case 'not_found': return `${base} ${base}--not-found`
      case 'not_empty': return `${base} ${base}--not-empty`
      case 'has_firmlink': return `${base} ${base}--has-firmlink`
      default: return `${base} ${base}--error`
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
    <div className="nodeshell-hopper">
      <div className="nodeshell-hopper__description">
        <p>A smarter nodeshell deletion implementation.</p>
        <p>
          Copy and paste from the nodeshells marked for destruction lists.
          Enter one nodeshell title per line. <strong>DO NOT</strong> separate them by pipes.
        </p>
        <p><strong>Note:</strong> This operation may take some time for large lists.</p>
      </div>

      <ul className="nodeshell-hopper__feature-list">
        <li>Checks to see if it's an E2node</li>
        <li>Checks to see whether it is empty</li>
        <li>Checks for firmlinks</li>
        <li>Deletes the nodeshell if all checks pass</li>
      </ul>

      <form onSubmit={handleSubmit} className="nodeshell-hopper__form">
        <textarea
          value={nodeshells}
          onChange={(e) => setNodeshells(e.target.value)}
          className="nodeshell-hopper__textarea"
          placeholder="Enter nodeshell titles, one per line..."
          disabled={loading}
        />
        <button
          type="submit"
          className={`nodeshell-hopper__button ${loading ? 'nodeshell-hopper__button--disabled' : ''}`}
          disabled={loading || !nodeshells.trim()}
        >
          {loading ? 'Processing...' : 'Whack em all!'}
        </button>
      </form>

      {error && (
        <div className="nodeshell-hopper__result-item nodeshell-hopper__result-item--error">
          {error}
        </div>
      )}

      {results && (
        <div className="nodeshell-hopper__results">
          <div className="nodeshell-hopper__summary">
            <h3 className="nodeshell-hopper__summary-title">Results Summary</h3>
            <ul>
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
            <div key={index} className={getResultClassName(result.status)}>
              <strong>{result.title}</strong> - [{getStatusLabel(result.status)}] {result.message}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

export default TheNodeshellHopper
