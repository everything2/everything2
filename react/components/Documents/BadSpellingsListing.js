import React from 'react';

const BadSpellingsListing = ({ data }) => {
  const {
    spellings = [],
    shown_count,
    total_count,
    user_has_disabled = false,
    is_admin = false,
    is_editor = false,
    setting_node_id,
    error,
    message
  } = data;

  // Handle errors
  if (error === 'config') {
    return (
      <div style={styles.container}>
        <p style={styles.error}>{message}</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p>
        If you have the option enabled to show <strong>common bad spellings</strong> in your writeups,
        common bad spellings will be flagged and displayed you are looking at your writeup by itself
        (as opposed to the e2node, which may contain other noders' writeups).
      </p>

      <p>
        This option can be toggled at{' '}
        <a href="/?node=Settings">Settings</a> in the Writeup Hints section.
        You currently have it{' '}
        {user_has_disabled ? (
          <span style={styles.warning}>disabled, which is not recommended</span>
        ) : (
          <span>enabled, the recommended setting</span>
        )}.
      </p>

      {is_admin && (
        <p style={styles.adminNote}>
          (Site administrators can edit this setting at{' '}
          <a href={`/?node_id=${setting_node_id}`}>bad spellings en-US</a>.)
        </p>
      )}

      <p>
        Spelling errors and corrections:
      </p>

      <table style={styles.table}>
        <thead>
          <tr style={styles.headerRow}>
            <th style={styles.th}>invalid</th>
            <th style={styles.th}>correction</th>
          </tr>
        </thead>
        <tbody>
          {spellings.map((item, index) => (
            <tr key={index} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
              <td style={styles.td}>{item.invalid}</td>
              <td style={styles.td} dangerouslySetInnerHTML={{ __html: item.correction }} />
            </tr>
          ))}
        </tbody>
      </table>

      <p style={styles.summary}>
        ({shown_count} entries
        {is_editor && ` shown, ${total_count} total`})
      </p>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  warning: {
    color: '#dc3545',
    fontWeight: 'bold'
  },
  adminNote: {
    fontSize: '14px',
    color: '#507898'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '10px',
    marginBottom: '10px',
    border: '1px solid #dee2e6'
  },
  headerRow: {
    backgroundColor: '#f8f9f9'
  },
  th: {
    padding: '8px',
    textAlign: 'left',
    borderBottom: '2px solid #dee2e6',
    border: '1px solid #dee2e6',
    fontWeight: 'bold'
  },
  td: {
    padding: '6px 8px',
    border: '1px solid #dee2e6'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  summary: {
    fontSize: '14px',
    color: '#507898',
    marginTop: '10px'
  },
  error: {
    color: '#dc3545',
    fontWeight: 'bold'
  }
};

export default BadSpellingsListing;
