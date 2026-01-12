import React from 'react'
import NodeletContainer from '../NodeletContainer'
import MessageList from '../MessageList'
import MessageModal from '../MessageModal'
import { useActivityDetection } from '../../hooks/useActivityDetection'

const Messages = (props) => {
  const [messages, setMessages] = React.useState(props.initialMessages || [])
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState(null)
  const [showArchived, setShowArchived] = React.useState(false)
  const [modalOpen, setModalOpen] = React.useState(false)
  const [replyingTo, setReplyingTo] = React.useState(null)
  const [deleteConfirmOpen, setDeleteConfirmOpen] = React.useState(false)
  const [messageToDelete, setMessageToDelete] = React.useState(null)
  const [isReplyAll, setIsReplyAll] = React.useState(false)
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const pollInterval = React.useRef(null)
  const missedUpdate = React.useRef(false)

  if (!messages) {
    return (
      <NodeletContainer
        id={props.id}
      title="Messages"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p className="nodelet-empty">
          No messages available
        </p>
      </NodeletContainer>
    )
  }

  const loadMessages = React.useCallback(async (archived = false) => {
    setLoading(true)
    setError(null)

    try {
      const archiveParam = archived ? '&archive=1' : ''
      const response = await fetch(`/api/messages/?limit=10${archiveParam}`, {
        credentials: 'include',
        headers: {
          'X-Ajax-Idle': '1'
        }
      })

      if (!response.ok) {
        throw new Error('Failed to load messages')
      }

      const data = await response.json()
      setMessages(data)
      setShowArchived(archived)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  // Polling effect - refresh every 2 minutes when active and nodelet is expanded
  React.useEffect(() => {
    const shouldPoll = isActive && isMultiTabActive && !loading && props.nodeletIsOpen

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        loadMessages(showArchived)
      }, 120000) // 2 minutes
    } else {
      // If we're not polling because nodelet is collapsed, mark that we missed updates
      if (isActive && isMultiTabActive && !loading && !props.nodeletIsOpen) {
        missedUpdate.current = true
      }

      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }

    return () => {
      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }
  }, [isActive, isMultiTabActive, loading, props.nodeletIsOpen, showArchived, loadMessages])

  // Uncollapse detection: refresh immediately when nodelet is uncollapsed after missing updates
  React.useEffect(() => {
    if (props.nodeletIsOpen && missedUpdate.current) {
      missedUpdate.current = false
      loadMessages(showArchived)
    }
  }, [props.nodeletIsOpen, showArchived, loadMessages])

  // Focus refresh: immediately refresh when page becomes visible
  React.useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && isActive) {
        loadMessages(showArchived)
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isActive, showArchived, loadMessages])

  const handleArchive = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/archive`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to archive message')
      }

      // Remove message from list
      setMessages(messages.filter(m => m.message_id !== messageId))
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDelete = (messageId) => {
    setMessageToDelete(messageId)
    setDeleteConfirmOpen(true)
  }

  const confirmDelete = async () => {
    try {
      const response = await fetch(`/api/messages/${messageToDelete}/action/delete`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to delete message')
      }

      // Remove message from list
      setMessages(messages.filter(m => m.message_id !== messageToDelete))
      setDeleteConfirmOpen(false)
      setMessageToDelete(null)
    } catch (err) {
      setError(err.message)
      setDeleteConfirmOpen(false)
      setMessageToDelete(null)
    }
  }

  const cancelDelete = () => {
    setDeleteConfirmOpen(false)
    setMessageToDelete(null)
  }

  const handleUnarchive = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/unarchive`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to unarchive message')
      }

      // Remove message from list
      setMessages(messages.filter(m => m.message_id !== messageId))
    } catch (err) {
      setError(err.message)
    }
  }

  const handleReply = (message, replyAll = false) => {
    setReplyingTo(message)
    setIsReplyAll(replyAll)
    setModalOpen(true)
  }

  const handleNewMessage = () => {
    setReplyingTo(null)
    setIsReplyAll(false)
    setModalOpen(true)
  }

  const handleSendMessage = async (recipient, messageText) => {
    try {
      const response = await fetch('/api/messages/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({
          for: recipient,
          message: messageText
        })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      // Check response body for blocking/error indicators
      const data = await response.json()

      // Check if user is being ignored (complete block)
      if (data.ignores) {
        throw new Error(`${recipient} is ignoring you`)
      }

      // Check for partial usergroup blocks (warnings, not errors)
      if (data.errors && Array.isArray(data.errors) && data.errors.length > 0) {
        // Count blocked members
        const blockedCount = data.errors.length
        const warningMsg = blockedCount === 1
          ? `Message sent, but 1 user is blocking you`
          : `Message sent, but ${blockedCount} users are blocking you`

        // Refresh messages list if sending to a usergroup (sender receives own message)
        if (data.poll_messages) {
          await loadMessages(showArchived)
        }

        // Return warning for partial success
        return { success: true, warning: warningMsg }
      }

      // Check for other errors (complete failures)
      if (data.errortext) {
        throw new Error(data.errortext)
      }

      // Refresh messages list if sending to a usergroup (sender receives own message)
      if (data.poll_messages) {
        await loadMessages(showArchived)
      }

      return true
    } catch (err) {
      console.error('Failed to send message:', err)
      throw err
    }
  }


  return (
    <NodeletContainer
      id={props.id}
      title="Messages"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {error && (
        <div className="nodelet-error">
          {error}
        </div>
      )}

      <div className="messages-toggle-row">
        <button
          onClick={() => loadMessages(false)}
          disabled={loading || !showArchived}
          className={`nodelet-btn${!showArchived ? ' nodelet-btn--active' : ''}`}
        >
          Inbox
        </button>
        <button
          onClick={() => loadMessages(true)}
          disabled={loading || showArchived}
          className={`nodelet-btn${showArchived ? ' nodelet-btn--active' : ''}`}
        >
          Archived
        </button>
      </div>

      {loading && (
        <div className="nodelet-loading">
          Loading messages...
        </div>
      )}

      {!loading && (
        <MessageList
          messages={messages}
          onReply={handleReply}
          onReplyAll={handleReply}
          onArchive={handleArchive}
          onUnarchive={handleUnarchive}
          onDelete={handleDelete}
          compact={false}
          chatOrder={true}
          showActions={{
            reply: true,
            replyAll: true,
            archive: true,
            unarchive: true,
            delete: true
          }}
        />
      )}

      {/* New Message and Message Inbox buttons */}
      <div className="nodelet-footer nodelet-btn-row">
        <button
          onClick={handleNewMessage}
          className="nodelet-btn nodelet-btn--primary"
        >
          Compose
        </button>
        <a
          href="/title/Message+Inbox"
          className="nodelet-btn nodelet-link-btn"
        >
          Inbox
        </a>
      </div>

      {/* Message composition modal */}
      <MessageModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        replyTo={replyingTo}
        onSend={handleSendMessage}
        initialReplyAll={isReplyAll}
      />

      {/* Delete confirmation modal */}
      {deleteConfirmOpen && (
        <div className="nodelet-modal-overlay" onClick={cancelDelete}>
          <div className="nodelet-modal" onClick={(e) => e.stopPropagation()}>
            <h3 className="nodelet-modal-title">
              Delete Message
            </h3>
            <p className="nodelet-modal-body">
              Are you sure you want to permanently delete this message? This action cannot be undone.
            </p>
            <div className="nodelet-modal-actions">
              <button onClick={cancelDelete} className="nodelet-btn">
                Cancel
              </button>
              <button onClick={confirmDelete} className="nodelet-btn nodelet-btn--danger">
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </NodeletContainer>
  )
}

export default Messages
