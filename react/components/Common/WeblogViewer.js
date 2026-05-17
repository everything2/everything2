import React, { useState, useCallback } from 'react'

const formatDate = (timestamp) => {
  if (!timestamp) return 'unknown'
  const date = new Date(timestamp)
  return date.toLocaleString()
}

/**
 * WeblogViewer - Shared component for viewing weblog archives
 * Styles in CSS: .weblog-viewer__*
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
    <div className="weblog-viewer">
      <div className="weblog-viewer__header">
        <h1 className="weblog-viewer__title">{pageTitle}</h1>
      </div>

      {error && <div className="weblog-viewer__error">{error}</div>}
      {unlinkError && <div className="weblog-viewer__error">{unlinkError}</div>}

      {/* Optional intro content */}
      {introContent && !viewWeblog && (
        <div className="weblog-viewer__intro">
          {introContent}
        </div>
      )}

      {/* If viewing a specific group */}
      {viewWeblog && viewGroupName && (
        <>
          <div className="weblog-viewer__viewing-header">
            <span className="weblog-viewer__viewing-title">
              Viewing items for <strong><a href={`/node/${viewWeblog}`}>{viewGroupName}</a></strong>
            </span>
            <a href={pageUrl} className="weblog-viewer__back-link">
              {backLinkText}
            </a>
          </div>

          {visibleEntries.length > 0 ? (
            <table className="weblog-viewer__table">
              <thead>
                <tr>
                  <th className="weblog-viewer__th">Node</th>
                  <th className="weblog-viewer__th">Time</th>
                  <th className="weblog-viewer__th">Linker</th>
                  {isAdmin && <th className="weblog-viewer__th">Unlink?</th>}
                </tr>
              </thead>
              <tbody>
                {visibleEntries.map((entry, index) => (
                  <tr key={entry.node_id} className={index % 2 === 0 ? 'weblog-viewer__even-row' : 'weblog-viewer__odd-row'}>
                    <td className="weblog-viewer__td">
                      <a href={`/node/${entry.node_id}`} className="weblog-viewer__node-link">
                        {entry.title}
                      </a>
                    </td>
                    <td className="weblog-viewer__td">
                      <span className="weblog-viewer__small-text">{formatDate(entry.timestamp)}</span>
                    </td>
                    <td className="weblog-viewer__td">
                      {entry.linker_name ? (
                        <a href={`/node/${entry.linker_id}`} className="weblog-viewer__node-link">
                          {entry.linker_name}
                        </a>
                      ) : (
                        <em>unknown</em>
                      )}
                    </td>
                    {isAdmin && (
                      <td className="weblog-viewer__td">
                        <button
                          className="weblog-viewer__unlink-btn"
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
            <div className="weblog-viewer__skipped-notice">
              {skippedCount} deleted node{skippedCount === 1 ? ' was' : 's were'} skipped
            </div>
          )}
        </>
      )}

      {/* Group list (show when not viewing a specific group) */}
      {!viewWeblog && (
        <div className="weblog-viewer__group-grid">
          {groups.map((group) => (
            <div key={group.node_id} className="weblog-viewer__group-item">
              <a
                href={`${pageUrl}?view_weblog=${group.node_id}`}
                className={viewWeblog === group.node_id ? 'weblog-viewer__group-link weblog-viewer__group-link--active' : 'weblog-viewer__group-link'}
              >
                {group.title}
              </a>
              <div className="weblog-viewer__group-count">
                ({group.count} node{group.count === 1 ? '' : 's'})
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Confirmation Modal */}
      {confirmModal && (
        <div className="weblog-viewer__modal-overlay" onClick={handleCancelUnlink}>
          <div className="weblog-viewer__modal" onClick={e => e.stopPropagation()}>
            <h3 className="weblog-viewer__modal-title">Confirm Unlink</h3>
            <p className="weblog-viewer__modal-text">
              Are you sure you want to unlink{' '}
              <span className="weblog-viewer__modal-node-title">{confirmModal.title}</span>{' '}
              from this group?
            </p>
            <div className="weblog-viewer__modal-buttons">
              <button
                className="weblog-viewer__modal-cancel-btn"
                onClick={handleCancelUnlink}
              >
                Cancel
              </button>
              <button
                className="weblog-viewer__modal-confirm-btn"
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
