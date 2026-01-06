import React, { useState } from 'react'
import LinkNode from './LinkNode'
import ConfirmModal from './ConfirmModal'
import { renderE2Content } from './Editor/E2HtmlSanitizer'
import { FaTrash, FaChevronDown } from 'react-icons/fa'

/**
 * WeblogEntry - Displays a single weblog entry
 * Similar to WriteupDisplay but simplified for weblog content
 */
const WeblogEntry = ({ entry, canRemove, onRemove, weblogId }) => {
  const [isRemoving, setIsRemoving] = useState(false)
  const [showConfirm, setShowConfirm] = useState(false)

  const { to_node, title, type, doctext, linkedtime, linkedby, author, author_user } = entry

  // Format date like legacy htmlcode parsetimestamp
  const formatDate = (timestamp) => {
    if (!timestamp) return null
    const date = new Date(timestamp)
    if (isNaN(date.getTime())) return null
    return date.toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric'
    })
  }

  // Get sanitized HTML content
  const getSanitizedHtml = (content) => {
    if (!content) return ''
    const result = renderE2Content(content)
    return result.html || ''
  }

  // Handle remove confirmation
  const handleRemoveClick = () => {
    setShowConfirm(true)
  }

  // Handle actual removal
  const handleConfirmRemove = async () => {
    setShowConfirm(false)
    setIsRemoving(true)

    try {
      const response = await fetch(`/api/weblog/${weblogId}/${to_node}`, {
        method: 'DELETE',
        credentials: 'same-origin'
      })

      const result = await response.json()

      if (result.success) {
        if (onRemove) onRemove(to_node)
      } else {
        alert(result.error || 'Failed to remove entry')
      }
    } catch (error) {
      alert('Error removing entry: ' + error.message)
    } finally {
      setIsRemoving(false)
    }
  }

  // Check if linkedby is different from author (show "linked by" attribution)
  const showLinkedBy = linkedby && author && linkedby.node_id !== author_user

  return (
    <article className="item weblog-entry" id={`weblog_${to_node}`}>
      {/* Entry header */}
      <header className="contentinfo contentheader">
        <table border="0" cellPadding="0" cellSpacing="0" width="100%">
          <tbody>
            <tr className="wu_header">
              {/* Type */}
              <td className="wu_type">
                <span className="type">
                  (<LinkNode nodeId={to_node} title={type || 'writeup'} />)
                </span>
              </td>
              {/* Title */}
              <td className="wu_title" style={{ fontWeight: 'bold' }}>
                <LinkNode nodeId={to_node} title={title} />
              </td>
              {/* Author */}
              <td className="wu_author">
                {author && (
                  <>
                    by{' '}
                    <strong>
                      <LinkNode nodeId={author.node_id} title={author.title} type="user" />
                    </strong>
                  </>
                )}
              </td>
              {/* Date */}
              <td style={{ textAlign: 'right' }} className="wu_dtcreate">
                <small className="date">{formatDate(linkedtime)}</small>
              </td>
            </tr>
          </tbody>
        </table>
      </header>

      {/* Entry content */}
      <div
        className="content"
        dangerouslySetInnerHTML={{ __html: getSanitizedHtml(doctext) }}
      />

      {/* Entry footer with metadata */}
      <footer className="contentinfo contentfooter">
        <table border="0" cellPadding="0" cellSpacing="0" width="100%">
          <tbody>
            <tr className="wu_footer">
              {/* Linked by attribution */}
              <td style={{ textAlign: 'left' }}>
                {showLinkedBy && (
                  <small className="linkedby" style={{ color: '#666' }}>
                    linked by{' '}
                    <LinkNode nodeId={linkedby.node_id} title={linkedby.title} type="user" />
                  </small>
                )}
              </td>
              {/* Remove button for admins/owners */}
              <td style={{ textAlign: 'right' }}>
                {canRemove && (
                  <button
                    onClick={handleRemoveClick}
                    disabled={isRemoving}
                    title="Remove from weblog"
                    style={{
                      background: 'none',
                      border: 'none',
                      cursor: isRemoving ? 'not-allowed' : 'pointer',
                      color: '#dc3545',
                      fontSize: '12px',
                      padding: '2px 6px',
                      opacity: isRemoving ? 0.5 : 1
                    }}
                  >
                    <FaTrash style={{ marginRight: '4px' }} />
                    {isRemoving ? 'removing...' : 'remove'}
                  </button>
                )}
              </td>
            </tr>
          </tbody>
        </table>
      </footer>

      {/* Confirm removal modal */}
      <ConfirmModal
        isOpen={showConfirm}
        onClose={() => setShowConfirm(false)}
        onConfirm={handleConfirmRemove}
        title="Remove Weblog Entry"
        message={`Are you sure you want to remove "${title}" from this weblog?`}
        confirmText="Remove"
        cancelText="Cancel"
        confirmColor="#dc3545"
      />
    </article>
  )
}

/**
 * Weblog - Displays weblog entries with pagination
 *
 * Props:
 *   weblog: { entries, has_more, can_remove, weblog_id }
 *   title: Optional title for the weblog section (default: none)
 */
const Weblog = ({ weblog, title }) => {
  const [entries, setEntries] = useState(weblog?.entries || [])
  const [hasMore, setHasMore] = useState(weblog?.has_more || false)
  const [isLoading, setIsLoading] = useState(false)
  const [offset, setOffset] = useState(weblog?.entries?.length || 0)

  const canRemove = weblog?.can_remove || false
  const weblogId = weblog?.weblog_id

  // If no weblog data or no entries, don't render
  if (!weblog || !entries || entries.length === 0) {
    return null
  }

  // Handle entry removal - remove from local state
  const handleEntryRemoved = (toNode) => {
    setEntries(entries.filter(e => e.to_node !== toNode))
  }

  // Load more entries
  const handleLoadMore = async () => {
    setIsLoading(true)

    try {
      const response = await fetch(`/api/weblog/${weblogId}?limit=5&offset=${offset}`, {
        credentials: 'same-origin'
      })

      const result = await response.json()

      if (result.success) {
        setEntries([...entries, ...result.entries])
        setHasMore(result.has_more)
        setOffset(offset + result.entries.length)
      } else {
        alert(result.error || 'Failed to load more entries')
      }
    } catch (error) {
      alert('Error loading entries: ' + error.message)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="weblog">
      {title && <h3 style={{ marginBottom: '16px' }}>{title}</h3>}

      {entries.map((entry) => (
        <WeblogEntry
          key={entry.to_node}
          entry={entry}
          canRemove={canRemove}
          onRemove={handleEntryRemoved}
          weblogId={weblogId}
        />
      ))}

      {/* Load more button */}
      {hasMore && (
        <div className="weblog-pagination" style={{ textAlign: 'center', margin: '16px 0' }}>
          <button
            onClick={handleLoadMore}
            disabled={isLoading}
            style={{
              padding: '8px 16px',
              fontSize: '13px',
              border: '1px solid #507898',
              borderRadius: '4px',
              backgroundColor: '#fff',
              color: '#507898',
              cursor: isLoading ? 'not-allowed' : 'pointer',
              opacity: isLoading ? 0.6 : 1,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            <FaChevronDown />
            {isLoading ? 'Loading...' : 'Load older entries'}
          </button>
        </div>
      )}
    </div>
  )
}

export default Weblog
