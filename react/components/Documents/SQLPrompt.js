import React, { useState } from 'react';

export default function SQLPrompt({ data }) {
  const [query, setQuery] = useState(data.query || '');
  const [formatStyle, setFormatStyle] = useState(data.formatStyle || '0');
  const [hideResults, setHideResults] = useState(data.hideResults || false);

  // Handle unauthorized access
  if (data.error === 'unauthorized') {
    return (
      <div style={{ padding: '20px', color: '#cc0000' }}>
        <h2>Access Denied</h2>
        <p>{data.message}</p>
      </div>
    );
  }

  const results = data.results;

  // Helper to render cell value based on format style
  const renderCellValue = (cell) => {
    const value = cell?.value;
    const isNull = cell?.is_null;
    const isNodeId = cell?.is_node_id;

    if (isNull) return 'NULL';
    if (value === '') return '';
    if (isNodeId) return value;
    return value;
  };

  // Render results in textarea format (format style 2)
  const renderTextareaFormat = () => {
    if (!results.rows || results.rows.length === 0) return '';

    let text = '';
    // Header row
    text += results.columns.join('\t') + '\n';

    // Data rows
    results.rows.forEach((row) => {
      text += results.columns.map(col => renderCellValue(row[col])).join('\t') + '\n';
    });

    return text;
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'monospace' }}>
      <h1>SQL Prompt</h1>
      <p style={{ color: '#666', fontStyle: 'italic' }}>
        Restricted administrative interface - Use with extreme caution
      </p>

      <form method="POST" action="">
        <input type="hidden" name="node" value="SQL Prompt" />
        <input type="hidden" name="displaytype" value="" />
        <input type="hidden" name="sexisgood" value="1" />

        <div style={{ marginBottom: '15px' }}>
          <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
            SQL Query:
          </label>
          <textarea
            name="sqlquery"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            rows={5}
            cols={80}
            className="expandable"
            style={{
              width: '100%',
              fontFamily: 'monospace',
              fontSize: '14px',
              padding: '8px',
              border: '1px solid #ccc',
              borderRadius: '4px'
            }}
            placeholder="Enter SQL query..."
          />
        </div>

        <div style={{ marginBottom: '15px', display: 'flex', gap: '15px', alignItems: 'center', flexWrap: 'wrap' }}>
          <div>
            <label style={{ marginRight: '8px' }}>Display format:</label>
            <select
              name="sqlprompt_wrap"
              value={formatStyle}
              onChange={(e) => setFormatStyle(e.target.value)}
              style={{ padding: '4px 8px' }}
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
            style={{
              padding: '6px 16px',
              backgroundColor: query.trim() ? '#4060b0' : '#999',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: query.trim() ? 'pointer' : 'not-allowed',
              fontWeight: 'bold'
            }}
          >
            Execute
          </button>
        </div>
      </form>

      {/* Display Results */}
      {results && (
        <div style={{ marginTop: '30px' }}>
          {results.error ? (
            <div style={{
              padding: '15px',
              backgroundColor: '#ffe6e6',
              border: '2px solid #cc0000',
              borderRadius: '4px',
              color: '#cc0000'
            }}>
              <h3 style={{ marginTop: 0 }}>Error ({results.error_type})</h3>
              <pre style={{ whiteSpace: 'pre-wrap', margin: 0 }}>{results.message}</pre>
              <p style={{ marginBottom: 0, marginTop: '10px', fontSize: '12px' }}>
                Elapsed time: {results.elapsed_time} seconds
              </p>
            </div>
          ) : (
            <>
              <div style={{ marginBottom: '10px', fontSize: '14px', color: '#666' }}>
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
                      style={{
                        width: '100%',
                        fontFamily: 'monospace',
                        fontSize: '12px',
                        padding: '8px',
                        border: '1px solid #ccc',
                        borderRadius: '4px'
                      }}
                    />
                    {results.rows_fetched > 0 && (
                      <p style={{ marginTop: '10px', fontSize: '13px', color: '#666' }}>
                        Fetched {results.rows_fetched} row{results.rows_fetched > 1 ? 's' : ''}
                      </p>
                    )}
                  </div>
                ) : (
                  /* Format Styles 0, 1: Table view */
                  <div style={{ overflowX: 'auto' }}>
                    <table
                      border="1"
                      cellPadding="8"
                      cellSpacing="0"
                      style={{
                        borderCollapse: 'collapse',
                        fontSize: '13px',
                        width: formatStyle === '1' ? '100%' : 'auto'
                      }}
                    >
                      <thead>
                        <tr style={{ backgroundColor: '#CC99CC' }}>
                          {results.columns.map((col, idx) => (
                            <td
                              key={idx}
                              align="center"
                              style={{ fontWeight: 'bold', padding: '8px' }}
                            >
                              {col}
                            </td>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {results.rows.map((row, rowIdx) => (
                          <tr key={rowIdx} style={{ backgroundColor: rowIdx % 2 === 0 ? '#f9f9f9' : 'white' }}>
                            {results.columns.map((col, colIdx) => {
                              const cell = row[col];
                              const value = cell?.value;
                              const isNull = cell?.is_null;
                              const isNodeId = cell?.is_node_id;

                              return (
                                <td key={colIdx} style={{ padding: '6px' }}>
                                  {isNull ? (
                                    <em style={{ color: '#999' }}>NULL</em>
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
                              );
                            })}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {results.rows_fetched > 0 && (
                      <p style={{ marginTop: '10px', fontSize: '13px', color: '#666' }}>
                        Fetched {results.rows_fetched} row{results.rows_fetched > 1 ? 's' : ''}
                      </p>
                    )}
                  </div>
                )
              ) : hideResults ? (
                <p style={{ fontStyle: 'italic', color: '#666' }}>
                  Results hidden
                </p>
              ) : (
                <div style={{
                  padding: '20px',
                  textAlign: 'center',
                  color: '#666',
                  backgroundColor: '#f5f5f5',
                  borderRadius: '4px'
                }}>
                  <em>No results found</em>
                </div>
              )}
            </>
          )}
        </div>
      )}

      <div style={{
        marginTop: '40px',
        padding: '15px',
        backgroundColor: '#fff3cd',
        border: '1px solid #ffc107',
        borderRadius: '4px',
        fontSize: '13px'
      }}>
        <strong>⚠️ Warning:</strong> This interface provides direct SQL access to the database.
        Queries can modify or delete data. Always test read-only queries first and use transactions
        for write operations when possible.
      </div>
    </div>
  );
}
