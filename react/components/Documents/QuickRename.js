import React, { useState } from 'react'

/**
 * QuickRename - Bulk e2node rename tool for editors
 * Styles in CSS: .quick-rename__*
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
    <div className="quick-rename">
      <div className="quick-rename__header">
        <h1 className="quick-rename__title">Quick Rename</h1>
      </div>

      <div className="quick-rename__description">
        <p className="quick-rename__description-main">
          <strong>Bulk rename e2nodes</strong> — Enter the current title on the left and the new title on the right.
          Each node will be renamed and automatically repaired.
        </p>
        <p className="quick-rename__description-sub">
          Leave rows blank to skip them. Only filled rows will be processed.
        </p>
      </div>

      {results && (
        <div className={results.error ? 'quick-rename__results--error' : 'quick-rename__results--success'}>
          {results.error ? (
            <p className="quick-rename__error-text">{results.error}</p>
          ) : (
            <>
              <p className="quick-rename__results-summary">
                Results: {results.counts?.renamed || 0} renamed,{' '}
                {results.counts?.not_found || 0} not found,{' '}
                {results.counts?.target_exists || 0} target exists,{' '}
                {results.counts?.no_change || 0} no change
              </p>
              <ul className="quick-rename__results-list">
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
        <table className="quick-rename__table">
          <thead>
            <tr>
              <th className="quick-rename__th quick-rename__th--number">#</th>
              <th className="quick-rename__th">Current Title</th>
              <th className="quick-rename__th quick-rename__th--arrow"></th>
              <th className="quick-rename__th">New Title</th>
            </tr>
          </thead>
          <tbody>
            {renames.map((rename, index) => {
              const isFilled = rename.from.trim() || rename.to.trim()
              return (
                <tr key={index} style={{ backgroundColor: index % 2 === 0 ? '#fff' : '#fafafa' }}>
                  <td className="quick-rename__td quick-rename__td--number">{index + 1}</td>
                  <td className="quick-rename__td">
                    <input
                      type="text"
                      value={rename.from}
                      onChange={(e) => handleChange(index, 'from', e.target.value)}
                      className={`quick-rename__input${isFilled ? ' quick-rename__input--filled' : ''}`}
                      disabled={isSubmitting}
                      placeholder="e.g. Teh Quick Brown Fox"
                    />
                  </td>
                  <td className="quick-rename__td--arrow">→</td>
                  <td className="quick-rename__td">
                    <input
                      type="text"
                      value={rename.to}
                      onChange={(e) => handleChange(index, 'to', e.target.value)}
                      className={`quick-rename__input${isFilled ? ' quick-rename__input--filled' : ''}`}
                      disabled={isSubmitting}
                      placeholder="e.g. The Quick Brown Fox"
                    />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>

        <div className="quick-rename__footer">
          <span className="quick-rename__hint">
            {filledCount > 0 ? `${filledCount} row${filledCount === 1 ? '' : 's'} to process` : 'Fill in rows above'}
          </span>
          <button
            type="submit"
            disabled={isSubmitting}
            className={`quick-rename__submit${isSubmitting ? ' quick-rename__submit--disabled' : ''}`}
          >
            {isSubmitting ? 'Processing...' : 'Rename All'}
          </button>
        </div>
      </form>
    </div>
  )
}

export default QuickRename
