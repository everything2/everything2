import React from 'react'
import LinkNode from './LinkNode'
import ParseLinks from './ParseLinks'

/**
 * MessageList - Reusable component for displaying private messages
 *
 * Used in:
 * - Messages nodelet (full version with 10 messages, archive/inbox toggle)
 * - Chatterbox nodelet (mini version with 5 messages, compact UI)
 */
const MessageList = (props) => {
  const {
    messages = [],
    onReply,
    onReplyAll,
    onArchive,
    onUnarchive,
    onDelete,
    compact = false,
    limit = null,
    showActions = {
      reply: true,
      replyAll: true,
      archive: true,
      unarchive: true,
      delete: true
    }
  } = props

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp)
    if (compact) {
      // Compact format for mini-messages: "12:34 PM"
      return date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit'
      })
    } else {
      // Full format for Messages nodelet: "Dec 25, 12:34 PM"
      return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }
  }

  const renderMessage = (message) => {
    const isArchived = message.archive

    return (
      <div
        key={message.message_id}
        id={`message_${message.message_id}`}
        style={{
          backgroundColor: compact ? '#fff' : '#f8f9fa',
          border: compact ? 'none' : '1px solid #dee2e6',
          borderBottom: compact ? '1px solid #eee' : '1px solid #dee2e6',
          borderRadius: compact ? '0' : '4px',
          padding: compact ? '6px 8px' : '8px',
          marginBottom: compact ? '0' : '8px',
          fontSize: compact ? '11px' : '12px'
        }}
      >
        <div style={{ marginBottom: '4px' }}>
          <strong>
            <LinkNode
              id={message.author_user.node_id}
              display={message.author_user.title}
            />
          </strong>
          <span style={{ color: '#6c757d', fontSize: compact ? '10px' : '11px', marginLeft: '8px' }}>
            {formatTimestamp(message.timestamp)}
          </span>
        </div>

        {message.for_usergroup && !compact && (
          <div style={{ fontSize: '11px', color: '#6c757d', marginBottom: '4px' }}>
            to group: <LinkNode
              id={message.for_usergroup.node_id}
              display={message.for_usergroup.title}
            />
          </div>
        )}

        <div style={{ marginBottom: compact ? '4px' : '6px' }}>
          <ParseLinks>{message.msgtext}</ParseLinks>
        </div>

        {!compact && (
          <div style={{ display: 'flex', gap: '6px', fontSize: '14px', flexWrap: 'wrap' }}>
            {!isArchived ? (
              <>
                {showActions.reply && onReply && (
                  <button
                    onClick={() => onReply(message, false)}
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
                )}
                {showActions.replyAll && onReplyAll && message.for_usergroup && message.for_usergroup.node_id > 0 && (
                  <button
                    onClick={() => onReplyAll(message, true)}
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
                {showActions.archive && onArchive && (
                  <button
                    onClick={() => onArchive(message.message_id)}
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
                )}
                {showActions.delete && onDelete && (
                  <button
                    onClick={() => onDelete(message.message_id)}
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
                )}
              </>
            ) : (
              <>
                {showActions.reply && onReply && (
                  <button
                    onClick={() => onReply(message, false)}
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
                )}
                {showActions.replyAll && onReplyAll && message.for_usergroup && message.for_usergroup.node_id > 0 && (
                  <button
                    onClick={() => onReplyAll(message, true)}
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
                {showActions.unarchive && onUnarchive && (
                  <button
                    onClick={() => onUnarchive(message.message_id)}
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
                )}
                {showActions.delete && onDelete && (
                  <button
                    onClick={() => onDelete(message.message_id)}
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
                )}
              </>
            )}
          </div>
        )}
      </div>
    )
  }

  const messagesToDisplay = limit ? messages.slice(0, limit) : messages

  if (messagesToDisplay.length === 0) {
    return (
      <div style={{
        padding: compact ? '8px' : '12px',
        fontSize: compact ? '11px' : '12px',
        color: '#999',
        fontStyle: 'italic',
        textAlign: compact ? 'left' : 'center'
      }}>
        No messages
      </div>
    )
  }

  // For compact mode (nodelets), reverse to show oldest first (chat-style)
  // For full display (Message Inbox page), keep API order (newest first)
  const displayMessages = compact
    ? messagesToDisplay.slice().reverse()
    : messagesToDisplay

  return (
    <div style={{ marginBottom: compact ? '0' : '0' }}>
      {displayMessages.map(message => renderMessage(message))}
    </div>
  )
}

export default MessageList
