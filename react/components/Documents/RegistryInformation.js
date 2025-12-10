import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * RegistryInformation - Show user's own registry entries
 * Displays all registries the current user has submitted data to
 */
const RegistryInformation = ({ data }) => {
  const { entries = [], has_entries, is_guest, error } = data

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
        This page shows all the registries you have submitted entries to.
      </p>

      {!has_entries ? (
        <div style={styles.emptyState}>
          <p>You haven't submitted any registry entries yet.</p>
          <p>
            Browse <a href="/title/The+Registries" style={styles.link}>The Registries</a> to find registries you can join.
          </p>
        </div>
      ) : (
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Registry</th>
              <th style={styles.th}>Your Data</th>
              <th style={styles.th}>Your Comments</th>
              <th style={styles.thCenter}>In Profile?</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry, idx) => (
              <tr key={entry.registry.node_id} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <a href={`/?node_id=${entry.registry.node_id}`} style={styles.link}>
                    {entry.registry.title}
                  </a>
                </td>
                <td style={styles.td}>{entry.data || '-'}</td>
                <td style={styles.td}>{entry.comments || '-'}</td>
                <td style={styles.tdCenter}>{entry.in_profile ? 'Yes' : 'No'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <RegistryFooter currentPage="your_entries" />
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '900px',
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
  emptyState: {
    padding: '30px',
    textAlign: 'center',
    color: '#6c757d',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px'
  },
  th: {
    padding: '10px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  thCenter: {
    padding: '10px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'center',
    width: '90px'
  },
  td: {
    padding: '8px 12px',
    borderBottom: '1px solid #eee',
    verticalAlign: 'top'
  },
  tdCenter: {
    padding: '8px 12px',
    borderBottom: '1px solid #eee',
    textAlign: 'center',
    verticalAlign: 'top'
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
  }
}

export default RegistryInformation
