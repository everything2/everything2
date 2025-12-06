import React from 'react';
import LinkNode from '../LinkNode';

/**
 * Everything Finger - Who's online on Everything2
 *
 * Displays list of currently logged-in users with:
 * - Username and nickname
 * - Status flags (admin @, editor $, developer %, invisible, newbie days)
 * - Current room/location
 */
const EverythingFinger = ({ data }) => {
  const { users = [], total = 0 } = data;

  if (total === 0) {
    return (
      <div style={styles.container}>
        <em>No users are logged in!</em>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <p style={styles.intro}>
          There are currently <strong>{total}</strong> user{total !== 1 ? 's' : ''} on Everything2
        </p>
      </div>

      <div style={styles.tableWrapper}>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Who</th>
              <th style={styles.th}>What</th>
              <th style={styles.th}>Where</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, index) => (
              <tr key={user.user_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                {/* Who - Username */}
                <td style={styles.td}>
                  <LinkNode type="user" title={user.username} />
                </td>

                {/* What - Status flags */}
                <td style={styles.td}>
                  <div style={styles.flagsContainer}>
                    {user.flags.map((flag, idx) => (
                      <span key={idx}>
                        {flag.type === 'invisible' && (
                          <span style={styles.invisibleFlag}>{flag.label}</span>
                        )}
                        {flag.type === 'admin' && (
                          <span style={styles.roleFlag} title="Administrator">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'editor' && (
                          <span style={styles.roleFlag} title="Content Editor">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'developer' && (
                          <span style={styles.roleFlag} title="Developer">
                            {flag.label}
                          </span>
                        )}
                        {flag.type === 'newbie' && (
                          <span
                            style={flag.highlight ? styles.newbieHighlight : styles.newbie}
                            title={`Account is ${flag.label} days old`}
                          >
                            {flag.label}
                          </span>
                        )}
                      </span>
                    ))}
                  </div>
                </td>

                {/* Where - Current room */}
                <td style={styles.td}>
                  {user.room ? (
                    <LinkNode type="room" title={user.room.title} />
                  ) : (
                    <span style={styles.outside}>outside</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    textAlign: 'center',
    marginBottom: '20px'
  },
  intro: {
    fontSize: '16px',
    color: '#38495e',
    margin: '0 0 20px 0'
  },
  tableWrapper: {
    overflowX: 'auto',
    borderRadius: '8px',
    border: '1px solid #dee2e6'
  },
  table: {
    width: '75%',
    margin: '0 auto',
    borderCollapse: 'collapse',
    fontSize: '14px',
    background: 'white'
  },
  th: {
    padding: '12px 16px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  td: {
    padding: '10px 16px',
    borderBottom: '1px solid #eee'
  },
  evenRow: {
    background: '#fff'
  },
  oddRow: {
    background: '#fafbfc'
  },
  flagsContainer: {
    display: 'flex',
    gap: '4px',
    alignItems: 'center'
  },
  invisibleFlag: {
    color: '#ff0000',
    fontSize: '13px'
  },
  roleFlag: {
    color: '#38495e',
    fontWeight: '600',
    fontSize: '14px'
  },
  newbie: {
    color: '#507898',
    fontSize: '13px'
  },
  newbieHighlight: {
    color: '#507898',
    fontSize: '13px',
    fontWeight: '700'
  },
  outside: {
    color: '#6c757d',
    fontStyle: 'italic'
  }
};

export default EverythingFinger;
