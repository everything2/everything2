import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RegistryInformation - Show user's own registry entries
 * Styles in CSS: .registry-info__*
 *
 * Displays all registries the current user has submitted data to
 */
const RegistryInformation = ({ data }) => {
  const { entries = [], has_entries, is_guest, error } = data

  // Guest message
  if (is_guest) {
    return (
      <div className="registry-info">
        <p className="registry-info__guest-message">
          ...would be shown here if you logged in.
        </p>
      </div>
    )
  }

  // Error message
  if (error) {
    return (
      <div className="registry-info">
        <div className="registry-info__error">
          <p>{error}</p>
        </div>
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
