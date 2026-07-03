import React, { useState } from 'react'

export default function SQLPrompt({ data }) {
  const [query, setQuery] = useState('')
  const [formatStyle, setFormatStyle] = useState(
    data.formatStyle != null ? String(data.formatStyle) : '0'
  )
  const [hideResults, setHideResults] = useState(false)
  const [results, setResults] = useState(null)
  const [running, setRunning] = useState(false)
  const [runError, setRunError] = useState(null)

  // Handle unauthorized access
  if (data.error === 'unauthorized') {
    return (
      <div className="sql-prompt__denied">
        <h2>Access Denied</h2>
        <p>{data.message}</p>
      </div>
    )
  }

  // Persist the display-format preference via the allowlisted preferences API
  // (#4442). Non-fatal on failure -- the choice still applies locally this session.
  const handleFormatChange = async (e) => {
    const value = e.target.value
    setFormatStyle(value)
    try {
      await fetch('/api/preferences', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ sqlprompt_wrap: value }),
      })
    } catch (err) {
      /* non-fatal */
    }
  }

  // Run the query through the root-gated API and render results client-side (#4442).
  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!query.trim()) return
    setRunning(true)
    setRunError(null)
    try {
      const res = await fetch('/api/sqlprompt/query', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({ query, hide_results: hideResults ? 1 : 0 }),
      })
      const json = res.ok ? await res.json() : null
      if (json && json.success) {
        setResults(json.results)
      } else {
        setRunError((json && json.error) || 'Query failed')
        setResults(null)
      }
    } catch (err) {
      setRunError(err.message || 'Query failed')
      setResults(null)
    } finally {
      setRunning(false)
    }
  }

  // Helper to render cell value based on format style
  const renderCellValue = (cell) => {
    if (cell?.is_null) return 'NULL'
    if (cell?.value === '') return ''
    return cell?.value
  }

  // Render results in textarea format (format style 2)
  const renderTextareaFormat = () => {
    if (!results || !results.rows || results.rows.length === 0) return ''

    let text = results.columns.join('\t') + '\n'
    results.rows.forEach((row) => {
      text += results.columns.map((col) => renderCellValue(row[col])).join('\t') + '\n'
    })
    return text
  }

  const tableClass = formatStyle === '1'
    ? 'sql-prompt__table sql-prompt__table--full-width'
    : 'sql-prompt__table'

  return (
    <div className="sql-prompt">
      <h1 className="sql-prompt__title">SQL Prompt</h1>
      <p className="sql-prompt__subtitle">
        Restricted administrative interface - Use with extreme caution
      </p>

      <form onSubmit={handleSubmit}>
        <div className="sql-prompt__form-group">
          <label className="sql-prompt__label">
            SQL Query:
          </label>
          <textarea
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            rows={5}
            cols={80}
            className="sql-prompt__textarea"
            placeholder="Enter SQL query..."
          />
        </div>

        <div className="sql-prompt__controls">
          <div>
            <label>Display format: </label>
            <select
              value={formatStyle}
              onChange={handleFormatChange}
              className="sql-prompt__select"
            >
              <option value="0">Table view</option>
              <option value="1">Variable width table</option>
              <option value="2">Copy-n-paste (textarea)</option>
            </select>
          </div>

          <label>
            <input
              type="checkbox"
              checked={hideResults}
              onChange={(e) => setHideResults(e.target.checked)}
            />
            {' '}Hide results
          </label>

          <button
            type="submit"
            disabled={running || !query.trim()}
            className="sql-prompt__submit"
          >
            {running ? 'Running…' : 'Execute'}
          </button>
        </div>
      </form>

      {runError && (
        <div className="sql-prompt__error">
          <pre>{runError}</pre>
        </div>
      )}

      {/* Display Results */}
      {results && (
        <div className="sql-prompt__results">
          {results.error ? (
            <div className="sql-prompt__error">
              <h3>Error ({results.error_type})</h3>
              <pre>{results.message}</pre>
              <p className="sql-prompt__fetched">
                Elapsed time: {results.elapsed_time} seconds
              </p>
            </div>
          ) : (
            <>
              <div className="sql-prompt__meta">
                <strong>Elapsed time:</strong> {results.elapsed_time} seconds
                {results.affected_rows > 0 && (
                  <span className="sql-prompt__affected-rows">
                    <strong>{results.affected_rows}</strong> row{results.affected_rows > 1 ? 's' : ''} affected
                  </span>
                )}
              </div>

              {results.rows && results.rows.length > 0 ? (
                formatStyle === '2' ? (
                  /* Format Style 2: Copy-n-paste textarea */
                  <div>
                    <textarea
                      readOnly
                      value={renderTextareaFormat()}
                      rows={Math.min(30, results.rows.length + 2)}
                      className="sql-prompt__textarea"
                    />
                    {results.rows_fetched > 0 && (
                      <p className="sql-prompt__fetched">
                        Fetched {results.rows_fetched} row{results.rows_fetched > 1 ? 's' : ''}
                      </p>
                    )}
                  </div>
                ) : (
                  /* Format Styles 0, 1: Table view */
                  <div className="sql-prompt__table-wrapper">
                    <table
                      className={tableClass}
                      border="1"
                      cellPadding="8"
                      cellSpacing="0"
                    >
                      <thead>
                        <tr>
                          {results.columns.map((col, idx) => (
                            <td key={idx} align="center">
                              {col}
                            </td>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {results.rows.map((row, rowIdx) => (
                          <tr
                            key={rowIdx}
                            className={rowIdx % 2 === 0 ? 'sql-prompt__row--even' : 'sql-prompt__row--odd'}
                          >
                            {results.columns.map((col, colIdx) => {
                              const cell = row[col]
                              const value = cell?.value
                              const isNull = cell?.is_null
                              const isNodeId = cell?.is_node_id

                              return (
                                <td key={colIdx}>
                                  {isNull ? (
                                    <em className="sql-prompt__null">NULL</em>
                                  ) : value === '' ? (
                                    <span>&nbsp;</span>
                                  ) : isNodeId ? (
                                    <a href={`/?node_id=${value}`} target="_blank" rel="noopener noreferrer">
                                      <code>{value}</code>
                                    </a>
                                  ) : (
                                    <code>{value}</code>
                                  )}
                                </td>
                              )
                            })}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {results.rows_fetched > 0 && (
                      <p className="sql-prompt__fetched">
                        Fetched {results.rows_fetched} row{results.rows_fetched > 1 ? 's' : ''}
                      </p>
                    )}
                  </div>
                )
              ) : hideResults ? (
                <p className="sql-prompt__hidden">
                  Results hidden
                </p>
              ) : (
                <div className="sql-prompt__empty">
                  <em>No results found</em>
                </div>
              )}
            </>
          )}
        </div>
      )}

      <div className="sql-prompt__warning">
        <strong>Warning:</strong> This interface provides direct SQL access to the database.
        Queries can modify or delete data. Always test read-only queries first and use transactions
        for write operations when possible.
      </div>
    </div>
  )
}
