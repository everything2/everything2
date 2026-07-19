import React, { useState, useEffect } from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RecentRegistryEntries - Show recent entries across all registries
 * Styles in CSS: .recent-registry-entries__*
 *
 * Fetch-driven (#4548): the Page is a pure gate; this fetches GET /api/recent_registry_entries.
 * Login-required: the API returns state:'guest' for guests.
 */
const RecentRegistryEntries = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/recent_registry_entries', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="recent-registry-entries"><p>Loading...</p></div>
  }

  const { state, entries = [] } = data || {}

  if (state === 'guest') {
    return (
      <div className="recent-registry-entries">
        <p className="recent-registry-entries__guest-message">
          ...would be shown here if you logged in.
        </p>
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
