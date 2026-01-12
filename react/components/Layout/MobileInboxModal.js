import React, { useState, useEffect, useCallback } from 'react'
import { FaTimes, FaInbox, FaArchive, FaPen, FaReply, FaReplyAll, FaTrash } from 'react-icons/fa'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'
import MessageModal from '../MessageModal'

/**
 * MobileInboxModal - Full-screen mobile inbox for messages
 *
 * Displays messages in a mobile-optimized drawer that slides up from bottom.
 * Includes inbox/archive toggle, message actions, and compose functionality.
 */
const MobileInboxModal = ({ isOpen, onClose, initialMessages = [], onMessagesUpdate }) => {
  const [messages, setMessages] = useState(initialMessages)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [showArchived, setShowArchived] = useState(false)
  const [composeOpen, setComposeOpen] = useState(false)
  const [replyingTo, setReplyingTo] = useState(null)
  const [isReplyAll, setIsReplyAll] = useState(false)
  const [deleteConfirmId, setDeleteConfirmId] = useState(null)

  // Fetch and report unread message count to parent
  const fetchUnreadCount = useCallback(async () => {
    if (!onMessagesUpdate) return

    try {
      const response = await fetch('/api/messages/count', {
        credentials: 'include',
        headers: { 'X-Ajax-Idle': '1' }
      })

      if (response.ok) {
        const data = await response.json()
        onMessagesUpdate(data.count || 0)
      }
    } catch (err) {
      // Silently fail - badge update is not critical
      console.warn('Failed to fetch message count:', err)
    }
  }, [onMessagesUpdate])

  // Load messages when modal opens or tab changes
  const loadMessages = useCallback(async (archived = false) => {
    setLoading(true)
    setError(null)

    try {
      const archiveParam = archived ? '&archive=1' : ''
      const response = await fetch(`/api/messages/?limit=20${archiveParam}`, {
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

      // Update unread count badge after loading messages
      fetchUnreadCount()
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [fetchUnreadCount])

  // Load fresh messages when modal opens
  useEffect(() => {
    if (isOpen) {
      loadMessages(showArchived)
    }
  }, [isOpen, loadMessages, showArchived])

  // Prevent body scroll when modal is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  const handleArchive = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/archive`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to archive message')
      }

      setMessages(messages.filter(m => m.message_id !== messageId))
      // Archiving reduces unread count
      fetchUnreadCount()
    } catch (err) {
      setError(err.message)
    }
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

      setMessages(messages.filter(m => m.message_id !== messageId))
      // Unarchiving increases unread count
      fetchUnreadCount()
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDelete = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/delete`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to delete message')
      }

      setMessages(messages.filter(m => m.message_id !== messageId))
      setDeleteConfirmId(null)
      // Deleting may change unread count (if was unarchived message)
      fetchUnreadCount()
    } catch (err) {
      setError(err.message)
      setDeleteConfirmId(null)
    }
  }

  const handleReply = (message, replyAll = false) => {
    setReplyingTo(message)
    setIsReplyAll(replyAll)
    setComposeOpen(true)
  }

  const handleNewMessage = () => {
    setReplyingTo(null)
    setIsReplyAll(false)
    setComposeOpen(true)
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

      const data = await response.json()

      if (data.ignores) {
        throw new Error(`${recipient} is ignoring you`)
      }

      if (data.errors && Array.isArray(data.errors) && data.errors.length > 0) {
        const blockedCount = data.errors.length
        const warningMsg = blockedCount === 1
          ? `Message sent, but 1 user is blocking you`
          : `Message sent, but ${blockedCount} users are blocking you`

        if (data.poll_messages) {
          await loadMessages(showArchived)
        }

        return { success: true, warning: warningMsg }
      }

      if (data.errortext) {
        throw new Error(data.errortext)
      }

      if (data.poll_messages) {
        await loadMessages(showArchived)
      }

      return true
    } catch (err) {
      console.error('Failed to send message:', err)
      throw err
    }
  }

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp)
    const now = new Date()
    const isToday = date.toDateString() === now.toDateString()

    if (isToday) {
      return date.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
      })
    }

    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    })
  }

  if (!isOpen) return null

  return (
    <div className="mobile-modal-overlay">
      <div className="mobile-modal-drawer">
        {/* Header */}
        <div className="mobile-modal-header">
          <h2 className="mobile-modal-title">Messages</h2>
          <button
            type="button"
            onClick={onClose}
            className="mobile-modal-close-btn"
            aria-label="Close inbox"
          >
            <FaTimes />
          </button>
        </div>

        {/* Tab bar */}
        <div className="mobile-modal-tab-bar">
          <button
            type="button"
            onClick={() => loadMessages(false)}
            className={`mobile-modal-tab${showArchived ? '' : ' mobile-modal-tab--active'}`}
          >
            <FaInbox className="mobile-modal-tab-icon" />
            Inbox
          </button>
          <button
            type="button"
            onClick={() => loadMessages(true)}
            className={`mobile-modal-tab${showArchived ? ' mobile-modal-tab--active' : ''}`}
          >
            <FaArchive className="mobile-modal-tab-icon" />
            Archived
          </button>
        </div>

        {/* Error display */}
        {error && (
          <div className="mobile-modal-error">
            {error}
          </div>
        )}

        {/* Message list */}
        <div className="mobile-message-list">
          {loading ? (
            <div className="mobile-modal-loading">Loading messages...</div>
          ) : messages.length === 0 ? (
            <div className="mobile-modal-empty">
              {showArchived ? 'No archived messages' : 'No messages'}
            </div>
          ) : (
            messages.map(message => (
              <div key={message.message_id} className="mobile-message-card">
                {/* Message header */}
                <div className="mobile-message-header">
                  <LinkNode
                    id={message.author_user.node_id}
                    display={message.author_user.title}
                  />
                  <span className="mobile-message-timestamp">
                    {formatTimestamp(message.timestamp)}
                  </span>
                </div>

                {/* Usergroup indicator */}
                {message.for_usergroup && message.for_usergroup.node_id > 0 && (
                  <div className="mobile-message-usergroup">
                    to <LinkNode
                      id={message.for_usergroup.node_id}
                      display={message.for_usergroup.title}
                    />
                  </div>
                )}

                {/* Message body */}
                <div className="mobile-message-body">
                  <ParseLinks>{message.msgtext}</ParseLinks>
                </div>

                {/* Action buttons */}
                <div className="mobile-message-actions">
                  <button
                    type="button"
                    onClick={() => handleReply(message, false)}
                    className="mobile-message-action-btn"
                    aria-label="Reply"
                  >
                    <FaReply />
                  </button>

                  {message.for_usergroup && message.for_usergroup.node_id > 0 && (
                    <button
                      type="button"
                      onClick={() => handleReply(message, true)}
                      className="mobile-message-action-btn"
                      aria-label="Reply all"
                    >
                      <FaReplyAll />
                    </button>
                  )}

                  {!message.archive ? (
                    <button
                      type="button"
                      onClick={() => handleArchive(message.message_id)}
                      className="mobile-message-action-btn"
                      aria-label="Archive"
                    >
                      <FaArchive />
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => handleUnarchive(message.message_id)}
                      className="mobile-message-action-btn"
                      aria-label="Unarchive"
                    >
                      <FaInbox />
                    </button>
                  )}

                  <button
                    type="button"
                    onClick={() => setDeleteConfirmId(message.message_id)}
                    className="mobile-message-action-btn mobile-message-action-btn--delete"
                    aria-label="Delete"
                  >
                    <FaTrash />
                  </button>
                </div>

                {/* Delete confirmation */}
                {deleteConfirmId === message.message_id && (
                  <div className="mobile-message-delete-confirm">
                    <span>Delete this message?</span>
                    <button
                      type="button"
                      onClick={() => handleDelete(message.message_id)}
                      className="mobile-message-confirm-delete-btn"
                    >
                      Yes
                    </button>
                    <button
                      type="button"
                      onClick={() => setDeleteConfirmId(null)}
                      className="mobile-message-cancel-delete-btn"
                    >
                      No
                    </button>
                  </div>
                )}
              </div>
            ))
          )}
        </div>

        {/* Compose button */}
        <button
          type="button"
          onClick={handleNewMessage}
          className="mobile-modal-compose-btn"
          aria-label="Compose new message"
        >
          <FaPen />
          <span>Compose</span>
        </button>

        {/* Footer links */}
        <div className="mobile-modal-footer">
          <a href="/title/Message+Inbox" className="mobile-modal-footer-link">
            Full Inbox
          </a>
        </div>
      </div>

      {/* Message composition modal */}
      <MessageModal
        isOpen={composeOpen}
        onClose={() => setComposeOpen(false)}
        replyTo={replyingTo}
        onSend={handleSendMessage}
        initialReplyAll={isReplyAll}
      />
    </div>
  )
}

export default MobileInboxModal
