import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * TheRegistries - List all registries by most recent entry
 * Styles in CSS: .the-registries__*
 * Shows registries that have entries, ordered by most recent submission
 * Optionally includes empty registries via toggle
 */
const TheRegistries = ({ data }) => {
  const { registries = [], count, is_guest, error, include_empty } = data

  // State for the toggle - initialize from server data
  const [showEmpty, setShowEmpty] = React.useState(Boolean(include_empty))

  // Handle toggle change - reload page with new parameter
  const handleToggle = () => {
    const newValue = !showEmpty
    setShowEmpty(newValue)
    // Update URL and reload
    const url = new URL(window.location.href)
    if (newValue) {
      url.searchParams.set('include_empty', '1')
    } else {
      url.searchParams.delete('include_empty')
    }
    window.location.href = url.toString()
  }

  // Guest message
  if (is_guest) {
    return (
      <div className="the-registries">
        <p className="the-registries__guest-message">
          ...first, you'd better log in.
        </p>
      </div>
    )
  }

  // Error message
  if (error) {
    return (
      <div className="the-registries">
        <div className="the-registries__error">
          <p>{error}</p>
        </div>
      </div>
    )
  }

  return (
    <div className="the-registries">
      <p className="the-registries__intro">
        Registries are listed in order of most recent entry.
      </p>

      {/* Toggle for including empty registries */}
      <div className="the-registries__toggle-container">
        <label className="the-registries__toggle-label">
          <input
            type="checkbox"
            checked={showEmpty}
            onChange={handleToggle}
            className="the-registries__toggle-input"
          />
          <span className="the-registries__toggle-text">Include empty registries</span>
        </label>
      </div>

      {count === 0 ? (
        <div className="the-registries__empty-state">
          <p>No registries found.</p>
        </div>
      ) : (
        <ul className="the-registries__list">
          {registries.map((registry) => (
            <li key={registry.node_id} className="the-registries__list-item">
              <a href={`/?node_id=${registry.node_id}`} className="the-registries__link">
                {registry.title}
              </a>
              {registry.entry_count === 0 && (
                <span className="the-registries__empty-badge">(empty)</span>
              )}
            </li>
          ))}
        </ul>
      )}

      <RegistryFooter currentPage="the_registries" />
    </div>
  )
}

export default TheRegistries
