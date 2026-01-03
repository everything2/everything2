import React from 'react'

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  count: {
    color: '#666',
    fontSize: '0.9rem',
    marginTop: '5px',
  },
  list: {
    marginLeft: '55px',
    listStyleType: 'decimal',
  },
  listItem: {
    marginBottom: '4px',
    lineHeight: '1.4',
  },
  userLink: {
    fontWeight: 'bold',
  },
  stats: {
    color: '#666',
    marginLeft: '8px',
  },
  emptyMessage: {
    padding: '20px',
    textAlign: 'center',
    color: '#666',
    fontStyle: 'italic',
  },
}

const RecalculatedUsers = ({ data }) => {
  const { users, count } = data?.recalculatedUsers || { users: [], count: 0 }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Users who have run Recalculate XP</h1>
        <div style={styles.count}>{count} user{count !== 1 ? 's' : ''} found</div>
      </div>

      {users.length === 0 ? (
        <div style={styles.emptyMessage}>
          No users have run the Recalculate XP function yet.
        </div>
      ) : (
        <ol style={styles.list}>
          {users.map((user) => (
            <li key={user.node_id} style={styles.listItem}>
              <a
                href={`/user/${encodeURIComponent(user.title)}`}
                title={user.title}
                style={styles.userLink}
              >
                {user.title}
              </a>
              <span style={styles.stats}>
                - Level: {user.level} - XP: {user.xp.toLocaleString()}
              </span>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

export default RecalculatedUsers
