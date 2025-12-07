import React from 'react';

const RecentUsers = ({ data, e2 }) => {
  const {
    users = [],
    user_count = 0
  } = data;

  const staffLink = '/?node=E2+staff&nodetype=superdoc';

  return (
    <div style={styles.container}>
      <p style={styles.intro}>
        The following is a list of users who have logged in over the last 24 hours.
      </p>

      <div style={styles.summary}>
        <strong>{user_count}</strong> user{user_count !== 1 ? 's' : ''} logged in within the last 24 hours
      </div>

      {users.length === 0 ? (
        <p style={styles.empty}>No users have logged in recently.</p>
      ) : (
        <table style={styles.table}>
          <thead>
            <tr style={styles.headerRow}>
              <th style={styles.thNum}>#</th>
              <th style={styles.thName}>Name</th>
              <th style={styles.thTitle}>Staff</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.user_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                <td style={styles.tdNum}>{index + 1}</td>
                <td style={styles.tdName}>
                  <a href={`/?node_id=${user.user_id}`} style={styles.userLink}>
                    {user.username}
                  </a>
                </td>
                <td style={styles.tdTitle}>
                  {Boolean(user.is_admin) && (
                    <a href={staffLink} title="e2gods" style={styles.badge}>@</a>
                  )}
                  {Boolean(user.is_editor) && (
                    <a href={staffLink} title="Content Editors" style={styles.badge}>$</a>
                  )}
                  {Boolean(user.is_chanop) && (
                    <a href={staffLink} title="chanops" style={styles.badge}>+</a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div style={styles.legend}>
        <span style={styles.legendItem}>
          <span style={styles.legendBadge}>@</span> = e2gods
        </span>
        <span style={styles.legendItem}>
          <span style={styles.legendBadge}>$</span> = Content Editors
        </span>
        <span style={styles.legendItem}>
          <span style={styles.legendBadge}>+</span> = chanops
        </span>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  intro: {
    marginBottom: '15px',
    color: '#507898'
  },
  summary: {
    marginBottom: '20px',
    padding: '10px 15px',
    background: '#e8eef3',
    border: '1px solid #38495e',
    borderRadius: '4px',
    fontSize: '14px'
  },
  empty: {
    color: '#507898',
    fontStyle: 'italic',
    padding: '20px',
    textAlign: 'center'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px'
  },
  headerRow: {
    backgroundColor: '#38495e',
    color: 'white'
  },
  thNum: {
    padding: '10px',
    textAlign: 'center',
    borderBottom: '2px solid #dee2e6',
    width: '60px'
  },
  thName: {
    padding: '10px',
    textAlign: 'left',
    borderBottom: '2px solid #dee2e6'
  },
  thTitle: {
    padding: '10px',
    textAlign: 'center',
    borderBottom: '2px solid #dee2e6',
    width: '100px'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  tdNum: {
    padding: '8px 10px',
    textAlign: 'center',
    borderBottom: '1px solid #dee2e6',
    color: '#507898'
  },
  tdName: {
    padding: '8px 10px',
    borderBottom: '1px solid #dee2e6'
  },
  tdTitle: {
    padding: '8px 10px',
    textAlign: 'center',
    borderBottom: '1px solid #dee2e6'
  },
  userLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  badge: {
    display: 'inline-block',
    padding: '2px 6px',
    margin: '0 2px',
    background: '#4060b0',
    color: 'white',
    textDecoration: 'none',
    borderRadius: '3px',
    fontWeight: 'bold',
    fontSize: '14px'
  },
  legend: {
    display: 'flex',
    gap: '20px',
    justifyContent: 'center',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '14px',
    color: '#507898'
  },
  legendItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '5px'
  },
  legendBadge: {
    display: 'inline-block',
    padding: '2px 6px',
    background: '#4060b0',
    color: 'white',
    borderRadius: '3px',
    fontWeight: 'bold',
    fontSize: '12px'
  }
};

export default RecentUsers;
