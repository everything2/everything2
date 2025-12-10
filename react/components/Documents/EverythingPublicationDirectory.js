import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything Publication Directory - E2 Publications debate discussions
 *
 * Shows debates for E2 Publications, sorted by most recent comment.
 * Restricted to thepub usergroup members.
 */
const EverythingPublicationDirectory = ({ data }) => {
  const { error, debates = [], can_create = false } = data

  if (error) {
    return (
      <div style={styles.container}>
        <p style={styles.error}>{error}</p>
      </div>
    )
  }

  const handleCreateDebate = (e) => {
    e.preventDefault()
    const title = e.target.elements.node.value.trim()
    if (!title) {
      alert('Please enter a title for the new discussion')
      return
    }

    // Submit the form to create a new debate
    e.target.submit()
  }

  return (
    <div style={styles.container}>
      <p>Discussions on E2 Publications, most recently commented listed first.</p>

      <p>The "restricted" column shows who may view/add to a discussion.</p>

      <table style={styles.table}>
        <thead>
          <tr style={styles.headerRow}>
            <th style={{ ...styles.th, width: '200px' }} colSpan="2">Title</th>
            <th style={{ ...styles.th, width: '80px' }}>Restricted</th>
            <th style={{ ...styles.th, width: '80px' }}>Author</th>
            <th style={{ ...styles.th, width: '100px' }}>Created</th>
            <th style={{ ...styles.th, width: '100px' }}>Last Updated</th>
          </tr>
        </thead>
        <tbody>
          {debates.length === 0 ? (
            <tr>
              <td colSpan="6" style={styles.emptyState}>
                No discussions found.
              </td>
            </tr>
          ) : (
            debates.map((debate) => (
              <tr key={debate.node_id} style={styles.row}>
                <td style={styles.td}>
                  <LinkNode nodeId={debate.node_id} title={debate.title} />
                </td>
                <td style={styles.td}>
                  <small>
                    (
                    <LinkNode
                      nodeId={debate.node_id}
                      title="compact"
                      params={{ displaytype: 'compact' }}
                    />
                    )
                  </small>
                </td>
                <td style={styles.td}>
                  <small>
                    <LinkNode nodeId={debate.restricted_id} title={debate.restricted_title} />
                  </small>
                </td>
                <td style={styles.td}>
                  <LinkNode nodeId={debate.author_id} title={debate.author_title} />
                </td>
                <td style={styles.td}>{debate.created}</td>
                <td style={styles.td}>{debate.latest_time}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      {can_create && (
        <div style={styles.createForm}>
          <p style={styles.createHeading}>
            <strong>Create a New Discussion:</strong>
          </p>

          <form method="post" onSubmit={handleCreateDebate}>
            <input type="hidden" name="op" value="new" />
            <input type="hidden" name="type" value="debate" />
            <input type="hidden" name="displaytype" value="edit" />
            <input type="hidden" name="debate_parent_debatecomment" value="0" />

            <div style={styles.formGroup}>
              <input
                type="text"
                name="node"
                size="50"
                maxLength="64"
                placeholder="Enter discussion title..."
                style={styles.input}
              />
              <br />
              <input
                type="submit"
                value="Create Debate"
                style={styles.submitButton}
              />
            </div>
          </form>
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  error: {
    color: '#8b0000',
    fontStyle: 'italic',
    padding: '10px',
    backgroundColor: '#ffe6e6',
    border: '1px solid #8b0000',
    borderRadius: '4px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px',
    marginBottom: '25px'
  },
  headerRow: {
    backgroundColor: '#dddddd'
  },
  th: {
    textAlign: 'left',
    padding: '8px 10px',
    fontWeight: '600',
    fontSize: '13px',
    border: '1px solid #ccc'
  },
  row: {
    borderBottom: '1px solid #dee2e6'
  },
  td: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #dee2e6'
  },
  emptyState: {
    fontStyle: 'italic',
    color: '#6c757d',
    textAlign: 'center',
    padding: '20px'
  },
  createForm: {
    marginTop: '25px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6'
  },
  createHeading: {
    marginBottom: '10px'
  },
  formGroup: {
    marginTop: '10px'
  },
  input: {
    padding: '6px 10px',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    fontSize: '13px',
    width: '100%',
    maxWidth: '500px'
  },
  submitButton: {
    marginTop: '10px',
    padding: '8px 16px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600'
  }
}

export default EverythingPublicationDirectory
