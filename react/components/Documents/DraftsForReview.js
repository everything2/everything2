import React from 'react';

const DraftsForReview = ({ data }) => {
  const { drafts = [], is_editor = false, error, message } = data;

  // Handle errors
  if (error === 'guest') {
    return (
      <div style={styles.container}>
        <p>Only <a href="/?node=Sign+Up">logged-in users</a> can see drafts.</p>
      </div>
    );
  }

  if (error === 'config') {
    return (
      <div style={styles.container}>
        <p style={styles.error}>{message}</p>
      </div>
    );
  }

  // Format timestamp to readable date
  const formatDate = (timestamp) => {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  // Format latest note for tooltip
  const formatNote = (noteText) => {
    if (!noteText) return '';
    return noteText;
  };

  return (
    <div style={styles.container}>
      {drafts.length === 0 ? (
        <p>No drafts are currently awaiting review.</p>
      ) : (
        <table style={styles.table}>
          <thead>
            <tr style={styles.headerRow}>
              <th style={styles.th}>Draft</th>
              <th style={styles.thDate}>For review since</th>
              {is_editor && (
                <th style={styles.thNotes}>Notes</th>
              )}
            </tr>
          </thead>
          <tbody>
            {drafts.map((draft, index) => (
              <tr key={index} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                <td style={styles.td}>
                  <a href={`/?node=${encodeURIComponent(draft.title)}`}>
                    {draft.title}
                  </a>
                  {' by '}
                  <a href={`/?node_id=${draft.author_id}`}>
                    {draft.author}
                  </a>
                </td>
                <td style={styles.tdDate}>
                  {formatDate(draft.publishtime)}
                </td>
                {is_editor && (
                  <td style={styles.tdNotes}>
                    {draft.notecount > 0 ? (
                      <a
                        href={`/?node=${encodeURIComponent(draft.title)}#nodenotes`}
                        title={`${draft.notecount} notes; latest: ${formatNote(draft.latestnote)}`}
                      >
                        {draft.notecount}
                      </a>
                    ) : (
                      <span>&nbsp;</span>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}
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
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '14px'
  },
  headerRow: {
    backgroundColor: '#f8f9f9'
  },
  th: {
    padding: '8px',
    textAlign: 'left',
    borderBottom: '2px solid #dee2e6',
    fontWeight: 'bold'
  },
  thDate: {
    padding: '8px',
    textAlign: 'right',
    borderBottom: '2px solid #dee2e6',
    fontWeight: 'bold',
    whiteSpace: 'nowrap'
  },
  thNotes: {
    padding: '8px',
    textAlign: 'center',
    borderBottom: '2px solid #dee2e6',
    fontWeight: 'bold',
    width: '60px'
  },
  td: {
    padding: '6px 8px',
    borderBottom: '1px solid #dee2e6'
  },
  tdDate: {
    padding: '6px 8px',
    borderBottom: '1px solid #dee2e6',
    textAlign: 'right',
    whiteSpace: 'nowrap'
  },
  tdNotes: {
    padding: '6px 8px',
    borderBottom: '1px solid #dee2e6',
    textAlign: 'center',
    width: '60px'
  },
  evenRow: {
    backgroundColor: '#ffffff'
  },
  oddRow: {
    backgroundColor: '#f8f9f9'
  },
  error: {
    color: '#dc3545'
  }
};

export default DraftsForReview;
