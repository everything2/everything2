import React from 'react'
import ParseLinks from '../ParseLinks'

/**
 * SecurityMonitor - Security audit log viewer
 *
 * Admin tool for viewing security-related actions across the site.
 * Shows categorized logs for various security events.
 */
const SecurityMonitor = ({ data }) => {
  const {
    error,
    node_id,
    categories = [],
    viewing_type,
    entries = [],
    startat = 0,
    total = 0,
    page_size = 50
  } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Find the name of the currently viewed category
  const viewingCategory = viewing_type
    ? categories.find(c => c.node_id === viewing_type)
    : null

  return (
    <div className="security-monitor">
      {/* Category grid */}
      <div style={{ textAlign: 'center', marginBottom: '20px' }}>
        <table style={{ width: '90%', margin: '0 auto' }}>
          <tbody>
            {(() => {
              const rows = []
              for (let i = 0; i < categories.length; i += 5) {
                rows.push(
                  <tr key={i}>
                    {categories.slice(i, i + 5).map(cat => (
                      <td key={cat.node_id} style={{ textAlign: 'center' }}>
                        <div style={{
                          margin: '0.5em',
                          padding: '0.5em',
                          border: '1px solid #555',
                          borderRadius: '3px'
                        }}>
                          <a href={`/?node_id=${node_id}&sectype=${cat.node_id}`}>
                            {cat.name}
                          </a>
                          <br />
                          <small>({cat.count} entries)</small>
                        </div>
                      </td>
                    ))}
                  </tr>
                )
              }
              return rows
            })()}
          </tbody>
        </table>
      </div>

      {/* Log entries table */}
      {viewing_type && (
        <>
          <h3 style={{ textAlign: 'center' }}>
            {viewingCategory ? viewingCategory.name : 'Security Log'} Entries
          </h3>

          <div style={{ textAlign: 'center' }}>
            <table style={{
              margin: '0 auto',
              borderCollapse: 'collapse'
            }} className="logtable">
              <thead>
                <tr>
                  <th style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa', textAlign: 'left' }}>
                    <strong>Node</strong>
                  </th>
                  <th style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa', textAlign: 'left' }}>
                    <strong>User</strong>
                  </th>
                  <th style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa', textAlign: 'left' }}>
                    <strong>Time</strong>
                  </th>
                  <th style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa', textAlign: 'left' }}>
                    <strong>Details</strong>
                  </th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry, idx) => (
                  <tr key={idx}>
                    <td style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa' }}>
                      {entry.node_id ? (
                        <a href={`/?node_id=${entry.node_id}`}>{entry.node_title}</a>
                      ) : (
                        entry.node_title
                      )}
                    </td>
                    <td style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa' }}>
                      {entry.user_id ? (
                        <a href={`/?node_id=${entry.user_id}`}>{entry.user_title}</a>
                      ) : (
                        entry.user_title
                      )}
                    </td>
                    <td style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa' }}>
                      <small>{entry.time}</small>
                    </td>
                    <td style={{ padding: '0.5em 1em', borderBottom: '1px solid #aaa' }}>
                      <ParseLinks text={entry.details} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div style={{ textAlign: 'center', marginTop: '20px' }}>
            <hr style={{ width: '300px', margin: '20px auto' }} />
            <table style={{ width: '70%', margin: '0 auto' }}>
              <tbody>
                <tr>
                  <td style={{ width: '50%', textAlign: 'center' }}>
                    {startat > 0 ? (
                      <a href={`/?node_id=${node_id}&sectype=${viewing_type}&startat=${startat - page_size}`}>
                        {startat - page_size}-{startat}
                      </a>
                    ) : (
                      `${startat}-${Math.min(startat + page_size, total)}`
                    )}
                  </td>
                  <td style={{ width: '50%', textAlign: 'center' }}>
                    {startat + page_size < total ? (
                      <a href={`/?node_id=${node_id}&sectype=${viewing_type}&startat=${startat + page_size}`}>
                        {startat + page_size}-{Math.min(startat + page_size * 2, total)}
                      </a>
                    ) : (
                      '(end of list)'
                    )}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  )
}

export default SecurityMonitor
