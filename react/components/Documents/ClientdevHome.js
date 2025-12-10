import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * Clientdev Home - E2 Client Development homepage
 *
 * Shows registered E2 clients, registration form, and clientdev weblog.
 */
const ClientdevHome = ({ data, e2 }) => {
  const {
    clients = [],
    can_create = false,
    nwing = {},
    show_weblog = false,
    weblog = {}
  } = data

  const {
    entries: initialEntries = [],
    weblog_id = 0,
    can_remove = false,
    has_older = false,
    has_newer = false,
    next_older = 0,
    next_newer = 0
  } = weblog

  const [entries, setEntries] = useState(initialEntries)
  const [confirmModal, setConfirmModal] = useState(null)
  const [removing, setRemoving] = useState(false)

  const currentNodeId = e2?.node_id || data.node_id

  const handleRemoveClick = (entry) => {
    setConfirmModal(entry)
  }

  const handleConfirmRemove = async () => {
    if (!confirmModal || removing) return

    setRemoving(true)
    try {
      const response = await fetch(`/api/weblog/${weblog_id}/${confirmModal.node_id}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        }
      })

      const result = await response.json()

      if (result.success) {
        setEntries(entries.filter(e => e.node_id !== confirmModal.node_id))
        setConfirmModal(null)
      } else {
        alert('Failed to remove entry: ' + (result.error || 'Unknown error'))
      }
    } catch (err) {
      alert('Failed to remove entry: ' + err.message)
    } finally {
      setRemoving(false)
    }
  }

  const handleCancelRemove = () => {
    setConfirmModal(null)
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.heading}>Registered Clients</h2>

      <p>
        (See{' '}
        <LinkNode
          nodeId={0}
          title="Registering a client"
          params={{ node: 'clientdev', lastnode_id: 0 }}
        />{' '}
        for more information as to what this is about)
        <br />
      </p>

      <table style={styles.table}>
        <thead>
          <tr style={styles.headerRow}>
            <th style={styles.th}>title</th>
            <th style={styles.th}>version</th>
          </tr>
        </thead>
        <tbody>
          {clients.length === 0 ? (
            <tr>
              <td colSpan="2" style={styles.emptyState}>
                No registered clients yet.
              </td>
            </tr>
          ) : (
            clients.map((client) => (
              <tr key={client.node_id} style={styles.row}>
                <td style={styles.td}>
                  <LinkNode nodeId={client.node_id} title={client.title} />
                </td>
                <td style={styles.td}>{client.version}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      {Boolean(can_create) && (
        <div style={styles.createForm}>
          <h2 style={styles.subheading}>Register your client:</h2>
          <form method="post">
            <input type="hidden" name="op" value="new" />
            <input type="hidden" name="type" value="e2client" />
            <input type="hidden" name="displaytype" value="edit" />
            <input
              type="text"
              name="node"
              size="25"
              placeholder="Client name..."
              style={styles.input}
            />
            <br />
            <input
              type="submit"
              value="Register Client"
              style={styles.submitButton}
            />
          </form>
        </div>
      )}

      <div style={styles.section}>
        <p>Things to (eventually) come:</p>
        <ol>
          <li>make debates work for general groups</li>
          <li>
            list of people, their programming language, the platform, and the
            project
          </li>
        </ol>
      </div>

      {Boolean(nwing.node_id) && (
        <p>
          <LinkNode
            nodeId={nwing.node_id}
            title="N-Wing Group Messages"
            params={{ displaytype: 'group' }}
          />
        </p>
      )}

      <hr style={styles.hr} />

      {Boolean(show_weblog) && entries.length > 0 && (
        <div style={styles.weblogSection}>
          <h2 style={styles.subheading}>Clientdev Weblog</h2>
          <div style={styles.weblog}>
            {entries.map((entry, index) => (
              <div key={entry.node_id || index} style={styles.item}>
                <div style={styles.header}>
                  <div style={styles.headerTop}>
                    <a
                      href={`/node/document/${encodeURIComponent(entry.title)}`}
                      style={styles.title}
                    >
                      {entry.title}
                    </a>
                    {Boolean(can_remove) && (
                      <button
                        onClick={() => handleRemoveClick(entry)}
                        style={styles.removeButton}
                        title="Remove from weblog"
                        onMouseOver={e => {
                          e.target.style.background = '#fff0f0'
                          e.target.style.borderColor = '#dc3545'
                          e.target.style.color = '#dc3545'
                        }}
                        onMouseOut={e => {
                          e.target.style.background = '#f8f9f9'
                          e.target.style.borderColor = '#dee2e6'
                          e.target.style.color = '#888888'
                        }}
                      >
                        remove
                      </button>
                    )}
                  </div>
                  <cite style={styles.byline}>
                    by{' '}
                    <a
                      href={`/user/${encodeURIComponent(entry.author)}`}
                      style={styles.authorLink}
                    >
                      {entry.author}
                    </a>
                  </cite>
                  <span style={styles.date}>
                    {formatDate(entry.linkedtime)}
                  </span>
                </div>
                <div
                  style={styles.content}
                  dangerouslySetInnerHTML={{ __html: entry.content }}
                />
              </div>
            ))}
          </div>

          {Boolean(has_newer || has_older) && (
            <div style={styles.moreLink}>
              {Boolean(has_newer) && (
                <a
                  href={`/node/${currentNodeId}?nextweblog=${next_newer}`}
                  style={styles.navLink}
                >
                  &larr; newer
                </a>
              )}
              {Boolean(has_newer && has_older) && <span style={styles.separator}> | </span>}
              {Boolean(has_older) && (
                <a
                  href={`/node/${currentNodeId}?nextweblog=${next_older}`}
                  style={styles.navLink}
                >
                  older &rarr;
                </a>
              )}
            </div>
          )}
        </div>
      )}

      {/* Confirmation Modal */}
      {confirmModal && (
        <div style={styles.modalOverlay} onClick={handleCancelRemove}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Remove Entry</h3>
            <p style={styles.modalText}>
              Are you sure you want to remove &ldquo;{confirmModal.title}&rdquo; from this weblog?
            </p>
            <p style={styles.modalNote}>
              This will not delete the document, just remove it from the weblog.
            </p>
            <div style={styles.modalButtons}>
              <button
                onClick={handleCancelRemove}
                style={styles.cancelButton}
                disabled={removing}
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmRemove}
                style={styles.confirmButton}
                disabled={removing}
              >
                {removing ? 'Removing...' : 'Remove'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

/**
 * Format a MySQL datetime string for display
 */
function formatDate(dateStr) {
  if (!dateStr) return ''

  try {
    // MySQL datetime format: "2025-12-06 00:22:26"
    const date = new Date(dateStr.replace(' ', 'T') + 'Z')
    if (isNaN(date.getTime())) return dateStr

    const options = {
      weekday: 'short',
      month: 'short',
      day: '2-digit',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    }

    return date.toLocaleString('en-US', options).replace(',', '')
  } catch (e) {
    return dateStr
  }
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  heading: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '15px'
  },
  subheading: {
    fontSize: '15px',
    fontWeight: 'bold',
    color: '#4060b0',
    marginTop: '20px',
    marginBottom: '10px'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px',
    marginBottom: '20px',
    border: '1px solid #000'
  },
  headerRow: {
    backgroundColor: '#dddddd'
  },
  th: {
    textAlign: 'left',
    padding: '6px 8px',
    fontWeight: '600',
    fontSize: '13px',
    border: '1px solid #000'
  },
  row: {
    borderBottom: '1px solid #ccc'
  },
  td: {
    padding: '4px 8px',
    fontSize: '13px',
    border: '1px solid #ccc'
  },
  emptyState: {
    fontStyle: 'italic',
    color: '#6c757d',
    textAlign: 'center',
    padding: '15px'
  },
  createForm: {
    marginTop: '25px',
    marginBottom: '25px'
  },
  input: {
    padding: '4px 8px',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    fontSize: '13px',
    marginBottom: '8px'
  },
  submitButton: {
    padding: '6px 12px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '13px',
    cursor: 'pointer',
    fontWeight: '600'
  },
  section: {
    marginTop: '20px',
    marginBottom: '20px'
  },
  hr: {
    width: '100%',
    marginTop: '20px',
    marginBottom: '20px',
    border: 0,
    borderTop: '1px solid #ccc'
  },
  weblogSection: {
    marginTop: '20px'
  },
  weblog: {
    marginBottom: '20px'
  },
  item: {
    marginBottom: '24px',
    paddingBottom: '16px'
  },
  header: {
    marginBottom: '10px',
    padding: '8px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  headerTop: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: '10px'
  },
  title: {
    display: 'block',
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none',
    marginBottom: '4px',
    flex: 1
  },
  removeButton: {
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '3px',
    color: '#888888',
    fontSize: '11px',
    cursor: 'pointer',
    padding: '3px 8px',
    textDecoration: 'none',
    transition: 'all 0.15s ease',
    flexShrink: 0
  },
  byline: {
    display: 'block',
    color: '#507898',
    fontStyle: 'normal'
  },
  authorLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  date: {
    display: 'block',
    color: '#888888',
    marginTop: '4px'
  },
  content: {
    padding: '0 8px'
  },
  moreLink: {
    textAlign: 'center',
    padding: '15px 0',
    borderTop: '1px solid #dee2e6',
    marginTop: '10px'
  },
  navLink: {
    color: '#4060b0',
    textDecoration: 'none',
    padding: '5px 10px'
  },
  separator: {
    color: '#888888'
  },
  // Modal styles
  modalOverlay: {
    position: 'fixed',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000
  },
  modal: {
    backgroundColor: '#ffffff',
    borderRadius: '8px',
    padding: '24px',
    maxWidth: '400px',
    width: '90%',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)'
  },
  modalTitle: {
    margin: '0 0 16px 0',
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e'
  },
  modalText: {
    margin: '0 0 8px 0',
    fontSize: '14px',
    color: '#111111'
  },
  modalNote: {
    margin: '0 0 20px 0',
    fontSize: '12px',
    color: '#888888',
    fontStyle: 'italic'
  },
  modalButtons: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '10px'
  },
  cancelButton: {
    padding: '8px 16px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    backgroundColor: '#ffffff',
    color: '#38495e',
    cursor: 'pointer',
    fontSize: '14px'
  },
  confirmButton: {
    padding: '8px 16px',
    border: 'none',
    borderRadius: '4px',
    backgroundColor: '#dc3545',
    color: '#ffffff',
    cursor: 'pointer',
    fontSize: '14px'
  }
}

export default ClientdevHome
