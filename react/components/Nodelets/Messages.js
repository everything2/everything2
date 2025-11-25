import React from 'react'
import NodeletContainer from '../NodeletContainer'
import ParseLinks from '../ParseLinks'
import LinkNode from '../LinkNode'
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
        title="Messages"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
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

      // Refresh messages list
      await loadMessages(showArchived)

      return true
    } catch (err) {
      console.error('Failed to send message:', err)
      throw err
    }
  }

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp)
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const renderMessage = (message) => {
    return (
      <div
        key={message.message_id}
        id={`message_${message.message_id}`}
        style={{
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '4px',
          padding: '8px',
          marginBottom: '8px',
          fontSize: '12px'
        }}
      >
        <div style={{ marginBottom: '4px' }}>
          <strong>
            <LinkNode
              id={message.author_user.node_id}
              display={message.author_user.title}
            />
          </strong>
          <span style={{ color: '#6c757d', fontSize: '11px', marginLeft: '8px' }}>
            {formatTimestamp(message.timestamp)}
          </span>
        </div>

        {message.for_usergroup && (
          <div style={{ fontSize: '11px', color: '#6c757d', marginBottom: '4px' }}>
            to group: <LinkNode
              id={message.for_usergroup.node_id}
              display={message.for_usergroup.title}
            />
          </div>
        )}

        <div style={{ marginBottom: '6px' }}>
          <ParseLinks>{message.msgtext}</ParseLinks>
        </div>

        <div style={{ display: 'flex', gap: '6px', fontSize: '14px', flexWrap: 'wrap' }}>
          {!message.archive ? (
            <>
              <button
                onClick={() => handleReply(message, false)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #667eea',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#667eea'
                }}
                title="Reply to sender"
              >
                ↩
              </button>
              {message.for_usergroup && message.for_usergroup.node_id > 0 && (
                <button
                  onClick={() => handleReply(message, true)}
                  style={{
                    padding: '4px 8px',
                    fontSize: '14px',
                    border: '1px solid #667eea',
                    borderRadius: '3px',
                    backgroundColor: '#fff',
                    cursor: 'pointer',
                    color: '#667eea'
                  }}
                  title="Reply to all group members"
                >
                  ↩↩
                </button>
              )}
              <button
                onClick={() => handleArchive(message.message_id)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #6c757d',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#6c757d'
                }}
                title="Archive message"
              >
                📦
              </button>
              <button
                onClick={() => handleDelete(message.message_id)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #dc3545',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#dc3545'
                }}
                title="Delete message"
              >
                🗑
              </button>
            </>
          ) : (
            <>
              <button
                onClick={() => handleReply(message, false)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #667eea',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#667eea'
                }}
                title="Reply to sender"
              >
                ↩
              </button>
              {message.for_usergroup && message.for_usergroup.node_id > 0 && (
                <button
                  onClick={() => handleReply(message, true)}
                  style={{
                    padding: '4px 8px',
                    fontSize: '14px',
                    border: '1px solid #667eea',
                    borderRadius: '3px',
                    backgroundColor: '#fff',
                    cursor: 'pointer',
                    color: '#667eea'
                  }}
                  title="Reply to all group members"
                >
                  ↩↩
                </button>
              )}
              <button
                onClick={() => handleUnarchive(message.message_id)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #6c757d',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#6c757d'
                }}
                title="Unarchive message"
              >
                📂
              </button>
              <button
                onClick={() => handleDelete(message.message_id)}
                style={{
                  padding: '4px 8px',
                  fontSize: '14px',
                  border: '1px solid #dc3545',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#dc3545'
                }}
                title="Delete message"
              >
                🗑
              </button>
            </>
          )}
        </div>
      </div>
    )
  }

  return (
    <NodeletContainer
      title="Messages"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {error && (
        <div style={{
          backgroundColor: '#fee',
          border: '1px solid #fcc',
          borderRadius: '4px',
          padding: '8px',
          marginBottom: '8px',
          fontSize: '11px',
          color: '#c33'
        }}>
          {error}
        </div>
      )}

      <div style={{ marginBottom: '8px' }}>
        <button
          onClick={() => loadMessages(false)}
          disabled={loading || !showArchived}
          style={{
            padding: '4px 12px',
            fontSize: '12px',
            border: '1px solid #dee2e6',
            borderRadius: '3px',
            backgroundColor: !showArchived ? '#e9ecef' : '#fff',
            cursor: !showArchived || loading ? 'not-allowed' : 'pointer',
            marginRight: '4px'
          }}
        >
          Inbox
        </button>
        <button
          onClick={() => loadMessages(true)}
          disabled={loading || showArchived}
          style={{
            padding: '4px 12px',
            fontSize: '12px',
            border: '1px solid #dee2e6',
            borderRadius: '3px',
            backgroundColor: showArchived ? '#e9ecef' : '#fff',
            cursor: showArchived || loading ? 'not-allowed' : 'pointer'
          }}
        >
          Archived
        </button>
      </div>

      {loading && (
        <div style={{ padding: '12px', fontSize: '12px', color: '#999', fontStyle: 'italic', textAlign: 'center' }}>
          Loading messages...
        </div>
      )}

      {!loading && messages.length === 0 && (
        <div style={{ padding: '12px', fontSize: '12px', color: '#999', fontStyle: 'italic' }}>
          No messages
        </div>
      )}

      {!loading && messages.length > 0 && (
        <div>
          {messages.slice().reverse().map(message => renderMessage(message))}
        </div>
      )}

      {/* New Message and Message Inbox buttons */}
      <div style={{
        marginTop: '12px',
        paddingTop: '12px',
        borderTop: '1px solid #dee2e6',
        display: 'flex',
        gap: '8px',
        justifyContent: 'center'
      }}>
        <button
          onClick={handleNewMessage}
          style={{
            padding: '6px 12px',
            fontSize: '12px',
            border: '1px solid #38495e',
            borderRadius: '4px',
            backgroundColor: '#38495e',
            color: '#fff',
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          ✉ Compose
        </button>
        <a
          href="/title/Message+Inbox"
          style={{
            padding: '6px 12px',
            fontSize: '12px',
            border: '1px solid #dee2e6',
            borderRadius: '4px',
            backgroundColor: '#fff',
            color: '#495057',
            textDecoration: 'none',
            display: 'inline-block'
          }}
        >
          📬 Inbox
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
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10000
          }}
          onClick={cancelDelete}
        >
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '8px',
              padding: '24px',
              maxWidth: '400px',
              width: '90%',
              boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 16px 0', color: '#333', fontSize: '18px' }}>
              Delete Message
            </h3>
            <p style={{ margin: '0 0 20px 0', fontSize: '14px', color: '#495057' }}>
              Are you sure you want to permanently delete this message? This action cannot be undone.
            </p>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={cancelDelete}
                style={{
                  padding: '8px 16px',
                  fontSize: '13px',
                  border: '1px solid #dee2e6',
                  borderRadius: '4px',
                  backgroundColor: '#fff',
                  color: '#495057',
                  cursor: 'pointer'
                }}
              >
                Cancel
              </button>
              <button
                onClick={confirmDelete}
                style={{
                  padding: '8px 16px',
                  fontSize: '13px',
                  border: 'none',
                  borderRadius: '4px',
                  backgroundColor: '#dc3545',
                  color: '#fff',
                  cursor: 'pointer',
                  fontWeight: 'bold'
                }}
              >
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
