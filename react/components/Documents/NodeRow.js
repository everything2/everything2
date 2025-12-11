import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Node Row - Deprecated editorial tool
 *
 * Shows writeups that have been removed from nodes and placed in the editorial queue.
 * This tool is part of the legacy editorial workflow and is scheduled for removal.
 */
const NodeRow = ({ data }) => {
  const {
    error,
    total_count,
    removed_by_user,
    entries = [],
    offset,
    interval,
    has_more,
    node_row_id
  } = data

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>{error}</div>
      </div>
    )
  }

  const hasPrev = offset > 0
  const prevOffset = Math.max(0, offset - interval)
  const nextOffset = offset + interval

  return (
    <div style={styles.container}>
      <div style={styles.deprecationNotice}>
        <strong>⚠️ DEPRECATED TOOL</strong>
        <p>
          This editorial tool is part of the legacy workflow and is scheduled for removal.
          Modern editorial processes should use alternative tools.
        </p>
      </div>

      <div style={styles.stats}>
        <p>
          There are <strong>{total_count}</strong> items waiting on Node Row.
          {' '}Of those, you removed <strong>{removed_by_user}</strong>.
        </p>
      </div>

      {entries.length === 0 ? (
        <p>No items currently on Node Row.</p>
      ) : (
        <>
          {entries.map((entry, idx) => (
            <div key={entry.weblog_id} style={styles.entry}>
              <div style={styles.entryHeader}>
                <LinkNode nodeId={entry.to_node} title={entry.node_title} />
                {entry.parent_node && (
                  <span style={styles.parentInfo}>
                    {' '}from <LinkNode nodeId={entry.parent_node.node_id} title={entry.parent_node.title} />
                  </span>
                )}
              </div>

              <div style={styles.entryMeta}>
                <span style={styles.byline}>
                  Linked by <LinkNode nodeId={entry.linkedby_user} title={entry.linkedby_title} />
                </span>
                <span style={styles.date}>{entry.linkedtime}</span>
              </div>

              {entry.content && (
                <div
                  style={styles.content}
                  dangerouslySetInnerHTML={{ __html: entry.content }}
                />
              )}

              <div style={styles.actions}>
                <a
                  href={`?node_id=${node_row_id}&source=${node_row_id}&to_node=${entry.to_node}&op=removeweblog`}
                  style={styles.removeLink}
                >
                  restore
                </a>
              </div>
            </div>
          ))}

          {(hasPrev || has_more) && (
            <div style={styles.pagination}>
              {hasPrev && (
                <a href={`?offset=${prevOffset}`} style={styles.link}>
                  ← newer
                </a>
              )}
              {hasPrev && has_more && <span style={{ margin: '0 10px' }}>|</span>}
              {has_more && (
                <a href={`?offset=${nextOffset}`} style={styles.link}>
                  older →
                </a>
              )}
            </div>
          )}
        </>
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
  deprecationNotice: {
    padding: '15px',
    backgroundColor: '#fff3cd',
    border: '2px solid #856404',
    borderRadius: '4px',
    marginBottom: '20px',
    color: '#856404'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  stats: {
    marginBottom: '20px',
    padding: '10px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  entry: {
    marginBottom: '30px',
    paddingBottom: '20px',
    borderBottom: '1px solid #ccc'
  },
  entryHeader: {
    fontSize: '15px',
    fontWeight: 'bold',
    marginBottom: '8px'
  },
  parentInfo: {
    fontSize: '13px',
    fontWeight: 'normal',
    color: '#666'
  },
  entryMeta: {
    fontSize: '12px',
    color: '#666',
    marginBottom: '10px'
  },
  byline: {
    marginRight: '15px'
  },
  date: {
    fontStyle: 'italic'
  },
  content: {
    marginTop: '10px',
    marginBottom: '10px',
    padding: '10px',
    backgroundColor: '#f8f9f9',
    borderLeft: '3px solid #507898',
    fontSize: '12px'
  },
  actions: {
    marginTop: '10px'
  },
  removeLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontSize: '12px'
  },
  pagination: {
    marginTop: '30px',
    textAlign: 'center',
    padding: '15px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: 'bold'
  }
}

export default NodeRow
