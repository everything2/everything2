import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RecentRegistryEntries - Show recent entries across all registries
 * Displays the last 100 registry entries from all registries
 */
const RecentRegistryEntries = ({ data }) => {
  const { entries = [], is_guest, error } = data

  // Guest message
  if (is_guest) {
    return (
      <div style={styles.container}>
        <p style={styles.guestMessage}>
          ...would be shown here if you logged in.
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
        The most recent registry entries from across Everything2.
      </p>

      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.th}>Registry</th>
            <th style={styles.th}>User</th>
            <th style={styles.th}>Data</th>
            <th style={styles.th}>Comments</th>
            <th style={styles.thCenter}>Profile?</th>
          </tr>
        </thead>
        <tbody>
          {entries.length === 0 ? (
            <tr>
              <td colSpan="5" style={styles.emptyCell}>
                <em>No registry entries found</em>
              </td>
            </tr>
          ) : (
            entries.map((entry, idx) => (
              <tr key={`${entry.registry.node_id}-${entry.user.node_id}`} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <a href={`/?node_id=${entry.registry.node_id}`} style={styles.link}>
                    {entry.registry.title}
                  </a>
                </td>
                <td style={styles.td}>
                  <a href={`/?node_id=${entry.user.node_id}`} style={styles.link}>
                    {entry.user.title}
                  </a>
                </td>
                <td style={styles.td} dangerouslySetInnerHTML={{ __html: entry.data || '-' }} />
                <td style={styles.td} dangerouslySetInnerHTML={{ __html: entry.comments || '-' }} />
                <td style={styles.tdCenter}>{entry.in_profile ? 'Yes' : 'No'}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div style={styles.summary}>
        Showing last 100 registry entries.
      </div>

      <RegistryFooter currentPage="recent" />
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '20px'
  },
  intro: {
    marginBottom: '20px',
    color: '#38495e',
    lineHeight: '1.5'
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
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '12px'
  },
  th: {
    padding: '8px 10px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  thCenter: {
    padding: '8px 10px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'center',
    width: '70px'
  },
  td: {
    padding: '8px 10px',
    borderBottom: '1px solid #eee',
    verticalAlign: 'middle'
  },
  tdCenter: {
    padding: '8px 10px',
    borderBottom: '1px solid #eee',
    textAlign: 'center',
    verticalAlign: 'middle'
  },
  emptyCell: {
    padding: '30px',
    textAlign: 'center',
    color: '#6c757d'
  },
  evenRow: {
    background: '#f8f9f9'
  },
  oddRow: {
    background: '#fff'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  summary: {
    fontSize: '12px',
    color: '#6c757d',
    textAlign: 'center',
    marginTop: '20px'
  }
}

export default RecentRegistryEntries
