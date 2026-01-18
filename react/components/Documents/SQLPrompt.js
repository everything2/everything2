import React, { useState } from 'react'

export default function SQLPrompt({ data }) {
  const [query, setQuery] = useState(data.query || '')
  const [formatStyle, setFormatStyle] = useState(data.formatStyle || '0')
  const [hideResults, setHideResults] = useState(data.hideResults || false)

  // Handle unauthorized access
  if (data.error === 'unauthorized') {
    return (
      <div className="sql-prompt__denied">
        <h2>Access Denied</h2>
        <p>{data.message}</p>
      </div>
    )
  }

  const results = data.results

  // Helper to render cell value based on format style
  const renderCellValue = (cell) => {
    const value = cell?.value
    const isNull = cell?.is_null

    if (isNull) return 'NULL'
    if (value === '') return ''
    return value
  }

  // Render results in textarea format (format style 2)
  const renderTextareaFormat = () => {
    if (!results.rows || results.rows.length === 0) return ''

    let text = ''
    // Header row
    text += results.columns.join('\t') + '\n'

    // Data rows
    results.rows.forEach((row) => {
      text += results.columns.map(col => renderCellValue(row[col])).join('\t') + '\n'
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

      <form method="POST" action="">
        <input type="hidden" name="node" value="SQL Prompt" />
        <input type="hidden" name="displaytype" value="" />
        <input type="hidden" name="sexisgood" value="1" />

        <div className="sql-prompt__form-group">
          <label className="sql-prompt__label">
            SQL Query:
          </label>
          <textarea
            name="sqlquery"
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
              name="sqlprompt_wrap"
              value={formatStyle}
              onChange={(e) => setFormatStyle(e.target.value)}
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
              name="hideresults"
              value="1"
              checked={hideResults}
              onChange={(e) => setHideResults(e.target.checked)}
            />
            {' '}Hide results
          </label>

          <button
            type="submit"
            disabled={!query.trim()}
            className="sql-prompt__submit"
          >
            Execute
          </button>
        </div>
      </form>

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
                  <span style={{ marginLeft: '20px' }}>
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
