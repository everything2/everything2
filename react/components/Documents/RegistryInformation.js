import React, { useState, useEffect } from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RegistryInformation - Show the current user's own registry entries
 * Styles in CSS: .registry-info__*
 *
 * Fetch-driven (#4548): the Page is a pure gate; this fetches GET /api/registry_information.
 * Login-required: the API returns state:'guest' for guests.
 */
const RegistryInformation = () => {
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/registry_information', { credentials: 'same-origin' })
      .then((r) => r.json())
      .then((j) => { if (!cancelled) { setData(j); setLoading(false) } })
      .catch(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return <div className="registry-info"><p>Loading...</p></div>
  }

  const { state, entries = [], has_entries } = data || {}

  if (state === 'guest') {
    return (
      <div className="registry-info">
        <p className="registry-info__guest-message">
          ...would be shown here if you logged in.
        </p>
      </div>
    )
  }

  return (
    <div className="registry-info">
      <p className="registry-info__intro">
        This page shows all the registries you have submitted entries to.
      </p>

      {!has_entries ? (
        <div className="registry-info__empty-state">
          <p>You haven't submitted any registry entries yet.</p>
          <p>
            Browse <a href="/title/The+Registries" className="registry-info__link">The Registries</a> to find registries you can join.
          </p>
        </div>
      ) : (
        <table className="registry-info__table">
          <thead>
            <tr>
              <th className="registry-info__th">Registry</th>
              <th className="registry-info__th">Your Data</th>
              <th className="registry-info__th">Your Comments</th>
              <th className="registry-info__th registry-info__th--center">In Profile?</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry, idx) => (
              <tr key={entry.registry.node_id} className={idx % 2 === 1 ? 'registry-info__even-row' : 'registry-info__odd-row'}>
                <td className="registry-info__td">
                  <a href={`/?node_id=${entry.registry.node_id}`} className="registry-info__link">
                    {entry.registry.title}
                  </a>
                </td>
                <td className="registry-info__td">{entry.data || '-'}</td>
                <td className="registry-info__td">{entry.comments || '-'}</td>
                <td className="registry-info__td registry-info__td--center">{entry.in_profile ? 'Yes' : 'No'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <RegistryFooter currentPage="your_entries" />
    </div>
  )
}

export default RegistryInformation
