import React from 'react'
import ParseLinks from '../ParseLinks'

/**
 * SecurityMonitor - Security audit log viewer
 *
 * Admin tool for viewing security-related actions across the site.
 * Shows categorized logs for various security events.
 * Styles are in CSS classes (security-monitor__*)
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
    ? categories.find(c => c.id === viewing_type)
    : null

  return (
    <div className="security-monitor">
      {/* Category grid */}
      <div className="security-monitor__categories">
        <table className="security-monitor__category-table">
          <tbody>
            {(() => {
              const rows = []
              for (let i = 0; i < categories.length; i += 5) {
                rows.push(
                  <tr key={i}>
                    {categories.slice(i, i + 5).map(cat => (
                      <td key={cat.id} className="security-monitor__category-cell">
                        <div className="security-monitor__category-box">
                          <a href={`/?node_id=${node_id}&sectype=${cat.id}`}>
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
          <h3 className="security-monitor__heading">
            {viewingCategory ? viewingCategory.name : 'Security Log'} Entries
          </h3>

          <div className="security-monitor__entries">
            <table className="security-monitor__log-table logtable">
              <thead>
                <tr>
                  <th className="security-monitor__th">
                    <strong>Subject</strong>
                  </th>
                  <th className="security-monitor__th">
                    <strong>User</strong>
                  </th>
                  <th className="security-monitor__th">
                    <strong>Time</strong>
                  </th>
                  <th className="security-monitor__th">
                    <strong>Details</strong>
                  </th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry, idx) => (
                  <tr key={idx}>
                    <td className="security-monitor__td">
                      {entry.subject_id ? (
                        <a href={`/?node_id=${entry.subject_id}`}>{entry.subject_title}</a>
                      ) : (
                        entry.subject_title
                      )}
                    </td>
                    <td className="security-monitor__td">
                      {entry.user_id ? (
                        <a href={`/?node_id=${entry.user_id}`}>{entry.user_title}</a>
                      ) : (
                        entry.user_title
                      )}
                    </td>
                    <td className="security-monitor__td">
                      <small>{entry.time}</small>
                    </td>
                    <td className="security-monitor__td">
                      <ParseLinks text={entry.details} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="security-monitor__pagination">
            <hr className="security-monitor__pagination-hr" />
            <table className="security-monitor__pagination-table">
              <tbody>
                <tr>
                  <td className="security-monitor__pagination-cell">
                    {startat > 0 ? (
                      <a href={`/?node_id=${node_id}&sectype=${viewing_type}&startat=${startat - page_size}`}>
                        {startat - page_size}-{startat}
                      </a>
                    ) : (
                      `${startat}-${Math.min(startat + page_size, total)}`
                    )}
                  </td>
                  <td className="security-monitor__pagination-cell">
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
