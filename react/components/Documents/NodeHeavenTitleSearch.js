import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeHeavenTitleSearch - Admin tool for searching deleted writeups by title
 *
 * Searches the Node Heaven database for writeups matching a title pattern.
 * Shows createtime, title, reputation, author, and killa user.
 */
const NodeHeavenTitleSearch = ({ data }) => {
  const {
    error,
    search_title: initialSearchTitle = '',
    results = [],
    total_count,
    self_kill_count,
    visit_node_id
  } = data

  const [searchTitle, setSearchTitle] = useState(initialSearchTitle)

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const handleSubmit = (e) => {
    // Let form submit naturally with GET parameters
  }

  return (
    <div style={styles.container}>
      <p>
        Welcome to Node Heaven, where you may sit and reconcile with your dear departed writeups.
      </p>

      <p>
        <strong>Note:</strong> It takes <em>up to</em> 48 hours for a writeup that was deleted to
        turn up in Node Heaven. Remember: first they must be <em>judged</em>. For that 48 hours
        they are in purgatory...
        <strong>
          <em>
            <LinkNode nodeId={203136} title="sleeping" />
          </em>
        </strong>
        .
      </p>

      <div style={styles.searchBox}>
        <p>Since you are a god, you can also see other nuked nodes.</p>
        <form method="get" onSubmit={handleSubmit} style={styles.form}>
          <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />
          <label>
            title:{' '}
            <input
              type="text"
              name="heaventitle"
              value={searchTitle}
              onChange={(e) => setSearchTitle(e.target.value)}
              size={32}
              style={styles.input}
            />
          </label>
          <button type="submit" style={styles.button}>
            Search
          </button>
        </form>
      </div>

      {initialSearchTitle && (
        <>
          <p style={styles.centerText}>Here are the little Angels:</p>

          {results.length === 0 ? (
            <p style={styles.centerText}>
              <em>No nodes by this title have been nuked</em>
            </p>
          ) : (
            <>
              <table style={styles.table}>
                <thead>
                  <tr>
                    <th style={styles.th}>Create Time</th>
                    <th style={styles.th}>Writeup Title</th>
                    <th style={styles.th}>Rep</th>
                    <th style={styles.th}>Killa</th>
                  </tr>
                </thead>
                <tbody>
                  {results.map((result) => (
                    <tr key={result.node_id}>
                      <td style={styles.td}>
                        <small>{result.createtime}</small>
                      </td>
                      <td style={styles.td}>
                        <a href={`?node_id=${visit_node_id}&visit_id=${result.node_id}`}>
                          {result.title}
                        </a>{' '}
                        by <LinkNode nodeId={result.author_user} title={result.author_title} />
                      </td>
                      <td style={styles.td}>{result.reputation}</td>
                      <td style={styles.td}>
                        {result.killa_title ? (
                          <LinkNode nodeId={result.killa_user} title={result.killa_title} />
                        ) : (
                          ''
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <p>
                {total_count} writeups, of which you killed {self_kill_count}.
              </p>
            </>
          )}
        </>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  searchBox: {
    padding: '15px',
    backgroundColor: '#f8f9f9',
    border: '1px solid #d3d3d3',
    borderRadius: '4px',
    marginBottom: '20px'
  },
  form: {
    marginTop: '10px'
  },
  input: {
    padding: '8px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    marginRight: '10px'
  },
  button: {
    padding: '8px 16px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px'
  },
  centerText: {
    textAlign: 'center'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '20px',
    border: '1px solid #d3d3d3'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left',
    border: '1px solid #38495e'
  },
  td: {
    border: '1px solid #d3d3d3',
    padding: '8px'
  }
}

export default NodeHeavenTitleSearch
