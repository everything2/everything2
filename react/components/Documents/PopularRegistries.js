import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * PopularRegistries - Show most popular registries by submission count
 * Displays a table of registries sorted by number of entries
 */
const PopularRegistries = ({ data }) => {
  const { registries = [], limit = 25 } = data

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        These are the most popular registries on Everything2, ranked by the number of
        user submissions they have received.
      </p>

      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.thCenter}>#</th>
            <th style={styles.th}>Registry</th>
            <th style={styles.thRight}>Submissions</th>
          </tr>
        </thead>
        <tbody>
          {registries.length === 0 ? (
            <tr>
              <td colSpan="3" style={styles.emptyCell}>
                <em>No registries found</em>
              </td>
            </tr>
          ) : (
            registries.map((registry, idx) => (
              <tr key={registry.node_id} style={idx % 2 === 1 ? styles.evenRow : styles.oddRow}>
                <td style={styles.tdCenter}>{idx + 1}</td>
                <td style={styles.td}>
                  <a href={`/?node_id=${registry.node_id}`} style={styles.link}>
                    {registry.title}
                  </a>
                </td>
                <td style={styles.tdRight}>{registry.submission_count}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div style={styles.summary}>
        Showing top {limit} registries by submission count.
      </div>

      <RegistryFooter currentPage="popular" />
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '700px',
    margin: '0 auto',
    padding: '20px'
  },
  intro: {
    marginBottom: '20px',
    color: '#38495e',
    lineHeight: '1.5'
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
    width: '50px'
  },
  thRight: {
    padding: '10px 12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'right',
    width: '120px'
  },
  td: {
    padding: '8px 12px',
    borderBottom: '1px solid #eee'
  },
  tdCenter: {
    padding: '8px 12px',
    borderBottom: '1px solid #eee',
    textAlign: 'center',
    color: '#6c757d'
  },
  tdRight: {
    padding: '8px 12px',
    borderBottom: '1px solid #eee',
    textAlign: 'right',
    fontWeight: '500'
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

export default PopularRegistries
