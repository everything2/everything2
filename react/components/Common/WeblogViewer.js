import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  intro: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  groupGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
    gap: '10px',
    marginBottom: '20px',
  },
  groupItem: {
    padding: '10px',
    backgroundColor: '#fff',
    border: '1px solid #ddd',
    borderRadius: '4px',
    textAlign: 'center',
  },
  groupLink: {
    color: '#007bff',
    textDecoration: 'none',
    fontWeight: 'bold',
  },
  groupLinkActive: {
    color: '#007bff',
    textDecoration: 'none',
    fontWeight: 'bold',
    backgroundColor: '#fff3cd',
    padding: '2px 6px',
    borderRadius: '4px',
  },
  groupCount: {
    fontSize: '11px',
    color: '#666',
    marginTop: '4px',
  },
  viewingHeader: {
    textAlign: 'center',
    marginBottom: '20px',
  },
  backLink: {
    fontSize: '14px',
    color: '#666',
    marginLeft: '10px',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px',
  },
  th: {
    textAlign: 'left',
    padding: '10px',
    border: '1px solid #ddd',
    backgroundColor: '#f8f9fa',
    fontWeight: 'bold',
  },
  td: {
    padding: '10px',
    border: '1px solid #ddd',
  },
  nodeLink: {
    color: '#007bff',
    textDecoration: 'none',
  },
  smallText: {
    fontSize: '12px',
    color: '#666',
  },
  unlinkBtn: {
    padding: '4px 8px',
    backgroundColor: '#dc3545',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '12px',
  },
  skippedNotice: {
    marginTop: '15px',
    padding: '10px',
    backgroundColor: '#f8d7da',
    border: '1px solid #f5c6cb',
    borderRadius: '4px',
    fontSize: '14px',
  },
  error: {
    padding: '10px',
    backgroundColor: '#f8d7da',
    color: '#721c24',
    borderRadius: '4px',
    marginBottom: '15px',
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
    zIndex: 1000,
  },
  modal: {
    backgroundColor: '#fff',
    borderRadius: '8px',
    padding: '24px',
    maxWidth: '400px',
    width: '90%',
    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
  },
  modalTitle: {
    margin: '0 0 16px 0',
    fontSize: '1.25rem',
    fontWeight: 'bold',
  },
  modalText: {
    margin: '0 0 20px 0',
    lineHeight: '1.5',
    color: '#333',
  },
  modalNodeTitle: {
    fontWeight: 'bold',
    color: '#007bff',
  },
  modalButtons: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '10px',
  },
  modalCancelBtn: {
    padding: '8px 16px',
    backgroundColor: '#6c757d',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  },
  modalConfirmBtn: {
    padding: '8px 16px',
    backgroundColor: '#dc3545',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  },
}

const formatDate = (timestamp) => {
  if (!timestamp) return 'unknown'
  const date = new Date(timestamp)
  return date.toLocaleString()
}

/**
 * WeblogViewer - Shared component for viewing weblog archives
 *
 * Props:
 * - pageTitle: The page title (e.g., "News Archives", "Usergroup Picks")
 * - pageUrl: The URL path to link back to (e.g., "/title/News+Archives")
 * - backLinkText: Text for the back link (e.g., "[back to archive menu]")
 * - introContent: Optional React node for intro text
 * - data: The weblog data object containing:
 *   - groups: Array of { node_id, title, count }
 *   - viewWeblog: Currently viewed weblog ID (or null)
 *   - viewGroupName: Name of currently viewed group
 *   - entries: Array of weblog entries
 *   - skippedCount: Number of skipped deleted nodes
 *   - isAdmin: Whether user can unlink entries
 *   - error: Error message if any
 * - emptyGroupMessage: Message when no entries (default: "No entries found.")
 * - emptyListMessage: Message when viewing group has no entries
 */
const WeblogViewer = ({
  pageTitle,
  pageUrl,
  backLinkText = '[back to list]',
  introContent,
  data = {},
  emptyGroupMessage = 'No entries found for this group.',
}) => {
  const {
    groups = [],
    viewWeblog,
    viewGroupName,
    entries = [],
    skippedCount = 0,
    isAdmin,
    error,
  } = data

  const [removedNodes, setRemovedNodes] = useState({})
  const [unlinkError, setUnlinkError] = useState(null)
  const [confirmModal, setConfirmModal] = useState(null) // { nodeId, title }

  const handleUnlinkClick = useCallback((nodeId, title) => {
    setConfirmModal({ nodeId, title })
  }, [])

  const handleConfirmUnlink = useCallback(async () => {
    if (!confirmModal) return

    const { nodeId } = confirmModal
    setConfirmModal(null)

    try {
      const response = await fetch('/api/usergrouppicks/unlink', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          weblog_id: viewWeblog,
          node_id: nodeId,
        }),
      })

      const result = await response.json()

      if (result.success) {
        setRemovedNodes(prev => ({ ...prev, [nodeId]: true }))
        setUnlinkError(null)
      } else {
        setUnlinkError(result.error || 'Failed to unlink node')
      }
    } catch (err) {
      setUnlinkError('Failed to connect to server')
    }
  }, [viewWeblog, confirmModal])

  const handleCancelUnlink = useCallback(() => {
    setConfirmModal(null)
  }, [])

  // Filter out removed nodes
  const visibleEntries = entries.filter(e => !removedNodes[e.node_id])

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>{pageTitle}</h1>
      </div>

      {error && <div style={styles.error}>{error}</div>}
      {unlinkError && <div style={styles.error}>{unlinkError}</div>}

      {/* Optional intro content */}
      {introContent && !viewWeblog && (
        <div style={styles.intro}>
          {introContent}
        </div>
      )}

      {/* If viewing a specific group */}
      {viewWeblog && viewGroupName && (
        <>
          <div style={styles.viewingHeader}>
            <span style={{ fontSize: '18px' }}>
              Viewing items for <strong><a href={`/node/${viewWeblog}`}>{viewGroupName}</a></strong>
            </span>
            <a href={pageUrl} style={styles.backLink}>
              {backLinkText}
            </a>
          </div>

          {visibleEntries.length > 0 ? (
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={styles.th}>Node</th>
                  <th style={styles.th}>Time</th>
                  <th style={styles.th}>Linker</th>
                  {isAdmin && <th style={styles.th}>Unlink?</th>}
                </tr>
              </thead>
              <tbody>
                {visibleEntries.map((entry, index) => (
                  <tr key={entry.node_id} style={{ backgroundColor: index % 2 === 0 ? '#fff' : '#f8f9fa' }}>
                    <td style={styles.td}>
                      <a href={`/node/${entry.node_id}`} style={styles.nodeLink}>
                        {entry.title}
                      </a>
                    </td>
                    <td style={styles.td}>
                      <span style={styles.smallText}>{formatDate(entry.timestamp)}</span>
                    </td>
                    <td style={styles.td}>
                      {entry.linker_name ? (
                        <a href={`/node/${entry.linker_id}`} style={styles.nodeLink}>
                          {entry.linker_name}
                        </a>
                      ) : (
                        <em>unknown</em>
                      )}
                    </td>
                    {isAdmin && (
                      <td style={styles.td}>
                        <button
                          style={styles.unlinkBtn}
                          onClick={() => handleUnlinkClick(entry.node_id, entry.title)}
                        >
                          unlink
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p>{emptyGroupMessage}</p>
          )}

          {skippedCount > 0 && (
            <div style={styles.skippedNotice}>
              {skippedCount} deleted node{skippedCount === 1 ? ' was' : 's were'} skipped
            </div>
          )}
        </>
      )}

      {/* Group list (show when not viewing a specific group) */}
      {!viewWeblog && (
        <div style={styles.groupGrid}>
          {groups.map((group) => (
            <div key={group.node_id} style={styles.groupItem}>
              <a
                href={`${pageUrl}?view_weblog=${group.node_id}`}
                style={viewWeblog === group.node_id ? styles.groupLinkActive : styles.groupLink}
              >
                {group.title}
              </a>
              <div style={styles.groupCount}>
                ({group.count} node{group.count === 1 ? '' : 's'})
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Confirmation Modal */}
      {confirmModal && (
        <div style={styles.modalOverlay} onClick={handleCancelUnlink}>
          <div style={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 style={styles.modalTitle}>Confirm Unlink</h3>
            <p style={styles.modalText}>
              Are you sure you want to unlink{' '}
              <span style={styles.modalNodeTitle}>{confirmModal.title}</span>{' '}
              from this group?
            </p>
            <div style={styles.modalButtons}>
              <button
                style={styles.modalCancelBtn}
                onClick={handleCancelUnlink}
              >
                Cancel
              </button>
              <button
                style={styles.modalConfirmBtn}
                onClick={handleConfirmUnlink}
              >
                Unlink
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default WeblogViewer
