import React, { useEffect } from 'react';

const DuplicatesFound = ({ data }) => {
  const { redirect_to_nothing_found, redirect_to_node, search_term, matches = [], lastnode_id } = data;

  // Handle redirects
  useEffect(() => {
    if (redirect_to_nothing_found) {
      // Redirect to nothing_found - this should be handled by the controller
      // but we can show a message as fallback
      return;
    }
    if (redirect_to_node) {
      window.location.href = `/?node_id=${redirect_to_node}${lastnode_id ? `&lastnode_id=${lastnode_id}` : ''}`;
    }
  }, [redirect_to_nothing_found, redirect_to_node, lastnode_id]);

  if (redirect_to_nothing_found) {
    return (
      <div style={styles.container}>
        <p>No matches found.</p>
      </div>
    );
  }

  if (redirect_to_node) {
    return (
      <div style={styles.container}>
        <p>Redirecting...</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <p style={styles.header}>
        Multiple nodes named "{search_term}" were found:
      </p>

      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.th}>node_id</th>
            <th style={styles.th}>title</th>
            <th style={styles.th}>type</th>
            <th style={styles.th}>author</th>
            <th style={styles.th}>createtime</th>
          </tr>
        </thead>
        <tbody>
          {matches.map((match, index) => (
            <tr key={match.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
              <td style={styles.td}>{match.node_id}</td>
              <td style={styles.td}>
                <a href={`/?node_id=${match.node_id}${lastnode_id ? `&lastnode_id=${lastnode_id}` : ''}`}>
                  {match.title}
                </a>
              </td>
              <td style={styles.td}>{match.type}</td>
              <td style={styles.td}>
                {match.author_user > 0 ? (
                  match.is_current_user ? (
                    <strong>
                      <a href={`/?node_id=${match.author_user}&lastnode_id=0`}>
                        {match.author_name}
                      </a>
                    </strong>
                  ) : (
                    <a href={`/?node_id=${match.author_user}&lastnode_id=0`}>
                      {match.author_name}
                    </a>
                  )
                ) : ''}
              </td>
              <td style={styles.td}>{match.createtime}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div style={styles.explanation}>
        <p>On Everything2, different things can have the same title. For example, a user could
        have the name "aardvark", but there could also be a page full of writeups called "aardvark".</p>

        <p>If you are looking for information about a topic, choose <strong>e2node</strong>;
        this is where people's writeups are shown.<br />
        If you want to see a user's profile, pick <strong>user</strong>.<br />
        Other types of page, such as <strong>superdoc</strong>, are special and may be
        interactive or help keep the site running.</p>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '1000px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    fontSize: '18px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '20px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '14px',
    background: 'white',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    marginBottom: '20px'
  },
  th: {
    padding: '12px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    textAlign: 'left'
  },
  td: {
    padding: '10px 12px',
    borderBottom: '1px solid #eee'
  },
  evenRow: {
    background: '#fff'
  },
  oddRow: {
    background: '#fafbfc'
  },
  explanation: {
    fontSize: '14px',
    lineHeight: '1.6',
    color: '#111111',
    marginTop: '20px'
  }
};

export default DuplicatesFound;
