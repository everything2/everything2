import React from 'react'
import LinkNode from '../LinkNode'

/**
 * GP Optouts - Display users who have opted out of the GP system
 *
 * Admin tool showing users who have disabled Group Points in their settings.
 * Shows username, level, and current GP for each opted-out user.
 */
const GpOptouts = ({ data }) => {
  const { users = [], error } = data

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>{error}</div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <h3 style={styles.heading}>Users who have opted out of the GP system</h3>

      {users.length === 0 ? (
        <p style={styles.emptyState}>No users have opted out of the GP system.</p>
      ) : (
        <ol style={styles.list}>
          {users.map((user) => (
            <li key={user.user_id} style={styles.listItem}>
              <LinkNode nodeId={user.user_id} title={user.username} />
              {' - '}
              Level: {user.level}; GP: {user.gp}
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px'
  },
  heading: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '15px'
  },
  error: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  emptyState: {
    fontStyle: 'italic',
    color: '#6c757d'
  },
  list: {
    marginLeft: '55px',
    paddingLeft: '0'
  },
  listItem: {
    marginBottom: '8px'
  }
}

export default GpOptouts
