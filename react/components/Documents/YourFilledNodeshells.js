import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Your Filled Nodeshells - Shows user's nodeshells that have been filled by others
 *
 * Displays nodeshells (e2nodes) created by the user that:
 * 1. Have been filled by someone else (have writeups)
 * 2. User doesn't have their own writeup in them
 */
const YourFilledNodeshells = ({ data }) => {
  const { nodeshells = [], count = 0 } = data

  return (
    <div style={styles.container}>
      <p>(Be sure to check out <a href="/title/Your+nodeshells" style={styles.link}>Your nodeshells</a>, too.)</p>

      <p>
        <strong>{count}</strong> nodeshell{count !== 1 ? 's' : ''} created by you which {count !== 1 ? 'have' : 'has'} been filled by someone else:
      </p>

      {nodeshells.length === 0 ? (
        <p style={styles.emptyState}>No filled nodeshells found.</p>
      ) : (
        <ul style={styles.list}>
          {nodeshells.map((n) => (
            <li key={n.node_id} style={styles.listItem}>
              <LinkNode nodeId={n.node_id} title={n.title} />
            </li>
          ))}
        </ul>
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
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  emptyState: {
    fontStyle: 'italic',
    color: '#6c757d'
  },
  list: {
    paddingLeft: '30px',
    marginTop: '15px'
  },
  listItem: {
    marginBottom: '6px'
  }
}

export default YourFilledNodeshells
