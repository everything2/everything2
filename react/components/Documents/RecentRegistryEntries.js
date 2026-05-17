import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RecentRegistryEntries - Show recent entries across all registries
 * Styles in CSS: .recent-registry-entries__*
 *
 * Displays the last 100 registry entries from all registries
 */
const RecentRegistryEntries = ({ data }) => {
  const { entries = [], is_guest, error } = data

  // Guest message
  if (is_guest) {
    return (
      <div className="recent-registry-entries">
        <p className="recent-registry-entries__guest-message">
          ...would be shown here if you logged in.
        </p>
      </div>
    )
  }

  // Error message
  if (error) {
    return (
      <div className="recent-registry-entries">
        <div className="recent-registry-entries__error">
          <p>{error}</p>
        </div>
      </div>
    )
  }

  return (
    <div className="recent-registry-entries">
      <p className="recent-registry-entries__intro">
        The most recent registry entries from across Everything2.
      </p>

      <table className="recent-registry-entries__table">
        <thead>
          <tr>
            <th className="recent-registry-entries__th">Registry</th>
            <th className="recent-registry-entries__th">User</th>
            <th className="recent-registry-entries__th">Data</th>
            <th className="recent-registry-entries__th">Comments</th>
            <th className="recent-registry-entries__th--center">Profile?</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 ? (
            <tr>
              <td colSpan="5" className="recent-registry-entries__empty-cell">
                <em>No registry entries found</em>
              </td>
            </tr>
          ) : (
            entries.map((entry, idx) => (
              <tr key={`${entry.registry.node_id}-${entry.user.node_id}`} className={idx % 2 === 1 ? 'recent-registry-entries__even-row' : 'recent-registry-entries__odd-row'}>
                <td className="recent-registry-entries__td">
                  <a href={`/?node_id=${entry.registry.node_id}`} className="recent-registry-entries__link">
                    {entry.registry.title}
                  </a>
                </td>
                <td className="recent-registry-entries__td">
                  <a href={`/?node_id=${entry.user.node_id}`} className="recent-registry-entries__link">
                    {entry.user.title}
                  </a>
                </td>
                <td className="recent-registry-entries__td" dangerouslySetInnerHTML={{ __html: entry.data || '-' }} />
                <td className="recent-registry-entries__td" dangerouslySetInnerHTML={{ __html: entry.comments || '-' }} />
                <td className="recent-registry-entries__td--center">{entry.in_profile ? 'Yes' : 'No'}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div className="recent-registry-entries__summary">
        Showing last 100 registry entries.
      </div>

      <RegistryFooter currentPage="recent" />
    </div>
  )
}

export default RecentRegistryEntries
