import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * TheRegistries - List all registries by most recent entry
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
      <div style={styles.container}>
        <p style={styles.guestMessage}>
          ...first, you'd better log in.
        </p>
      </div>
    )
  }

  // Error message
  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{error}</p>
        </div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        Registries are listed in order of most recent entry.
      </p>

      {/* Toggle for including empty registries */}
      <div style={styles.toggleContainer}>
        <label style={styles.toggleLabel}>
          <input
            type="checkbox"
            checked={showEmpty}
            onChange={handleToggle}
            style={styles.toggleInput}
          />
          <span style={styles.toggleSlider} data-checked={showEmpty} />
          <span style={styles.toggleText}>Include empty registries</span>
        </label>
      </div>

      {count === 0 ? (
        <div style={styles.emptyState}>
          <p>No registries found.</p>
        </div>
      ) : (
        <ul style={styles.list}>
          {registries.map((registry) => (
            <li key={registry.node_id} style={styles.listItem}>
              <a href={`/?node_id=${registry.node_id}`} style={styles.link}>
                {registry.title}
              </a>
              {registry.entry_count === 0 && (
                <span style={styles.emptyBadge}>(empty)</span>
              )}
            </li>
          ))}
        </ul>
      )}

      <RegistryFooter currentPage="the_registries" />
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px'
  },
  intro: {
    marginBottom: '20px',
    color: '#6c757d',
    fontStyle: 'italic'
  },
  toggleContainer: {
    marginBottom: '20px',
    padding: '12px',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  toggleLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    cursor: 'pointer',
    fontSize: '14px'
  },
  toggleInput: {
    width: '18px',
    height: '18px',
    cursor: 'pointer',
    accentColor: '#4060b0'
  },
  toggleText: {
    color: '#38495e'
  },
  guestMessage: {
    padding: '30px',
    fontStyle: 'italic',
    color: '#507898',
    textAlign: 'center',
    fontSize: '14px'
  },
  error: {
    padding: '20px',
    background: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
    borderRadius: '4px'
  },
  emptyState: {
    padding: '30px',
    textAlign: 'center',
    color: '#6c757d',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  list: {
    listStyle: 'disc',
    paddingLeft: '30px',
    lineHeight: '1.8'
  },
  listItem: {
    marginBottom: '4px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  emptyBadge: {
    marginLeft: '8px',
    fontSize: '12px',
    color: '#6c757d',
    fontStyle: 'italic'
  }
}

export default TheRegistries
