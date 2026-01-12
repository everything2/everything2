import React from 'react'
import LinkNode from './LinkNode'
import ParseLinks from './ParseLinks'

/**
 * MessageList - Reusable component for displaying private messages
 *
 * Used in:
 * - Messages nodelet (full version with 10 messages, archive/inbox toggle)
 * - Chatterbox nodelet (mini version with 5 messages, compact UI)
 * - Message Inbox page (full page view with pagination)
 *
 * Props:
 * - compact: Controls UI density (timestamps, styling). Default: false
 * - chatOrder: If true, reverse messages so newest is at BOTTOM (chat-style).
 *              Default: false (newest at TOP, traditional inbox style)
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
    chatOrder = false,
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
      // Compact format for mini-messages: "14:34" (24-hour time to save space)
      return date.toLocaleTimeString('en-US', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      })
    } else {
      // Full format for Messages nodelet: "Dec 25, 14:34" (24-hour time)
      return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      })
    }
  }

  const renderMessage = (message) => {
    const isArchived = message.archive
    const itemClass = compact ? 'message-list-item message-list-item--compact' : 'message-list-item'
    const timestampClass = compact ? 'message-list-timestamp message-list-timestamp--compact' : 'message-list-timestamp'
    const contentClass = compact ? 'message-list-content message-list-content--compact' : 'message-list-content'

    return (
      <div
        key={message.message_id}
        id={`message_${message.message_id}`}
        className={itemClass}
      >
        <div className="message-list-header">
          <strong>
            <LinkNode
              id={message.author_user.node_id}
              display={message.author_user.title}
            />
          </strong>
          <span className={timestampClass}>
            {formatTimestamp(message.timestamp)}
          </span>
        </div>

        {message.for_usergroup && !compact && (
          <div className="message-list-group-info">
            to group: <LinkNode
              id={message.for_usergroup.node_id}
              display={message.for_usergroup.title}
            />
          </div>
        )}

        <div className={contentClass}>
          <ParseLinks>{message.msgtext}</ParseLinks>
        </div>

        {!compact && (
          <div className="message-list-actions">
            {!isArchived ? (
              <>
                {showActions.reply && onReply && (
                  <button
                    onClick={() => onReply(message, false)}
                    className="message-list-action-btn message-list-action-btn--reply"
                    title="Reply to sender"
                  >
                    ↩
                  </button>
                )}
                {showActions.replyAll && onReplyAll && message.for_usergroup && message.for_usergroup.node_id > 0 && (
                  <button
                    onClick={() => onReplyAll(message, true)}
                    className="message-list-action-btn message-list-action-btn--reply"
                    title="Reply to all group members"
                  >
                    ↩↩
                  </button>
                )}
                {showActions.archive && onArchive && (
                  <button
                    onClick={() => onArchive(message.message_id)}
                    className="message-list-action-btn message-list-action-btn--archive"
                    title="Archive message"
                  >
                    📦
                  </button>
                )}
                {showActions.delete && onDelete && (
                  <button
                    onClick={() => onDelete(message.message_id)}
                    className="message-list-action-btn message-list-action-btn--delete"
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
                    className="message-list-action-btn message-list-action-btn--reply"
                    title="Reply to sender"
                  >
                    ↩
                  </button>
                )}
                {showActions.replyAll && onReplyAll && message.for_usergroup && message.for_usergroup.node_id > 0 && (
                  <button
                    onClick={() => onReplyAll(message, true)}
                    className="message-list-action-btn message-list-action-btn--reply"
                    title="Reply to all group members"
                  >
                    ↩↩
                  </button>
                )}
                {showActions.unarchive && onUnarchive && (
                  <button
                    onClick={() => onUnarchive(message.message_id)}
                    className="message-list-action-btn message-list-action-btn--archive"
                    title="Unarchive message"
                  >
                    📂
                  </button>
                )}
                {showActions.delete && onDelete && (
                  <button
                    onClick={() => onDelete(message.message_id)}
                    className="message-list-action-btn message-list-action-btn--delete"
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
    const emptyClass = compact ? 'message-list-empty message-list-empty--compact' : 'message-list-empty'
    return (
      <div className={emptyClass}>
        No messages
      </div>
    )
  }

  // chatOrder=true: reverse to show oldest first (chat-style, newest at bottom)
  // chatOrder=false: keep API order (newest first, traditional inbox at top)
  const displayMessages = chatOrder
    ? messagesToDisplay.slice().reverse()
    : messagesToDisplay

  return (
    <div>
      {displayMessages.map(message => renderMessage(message))}
    </div>
  )
}

export default MessageList
