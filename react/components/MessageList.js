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
    // When true (Sent tab), render the recipient (or group) in the header
    // instead of the author — the author is always the viewing user there
    // so showing it is just noise. Defaults to false to preserve every
    // existing caller's behavior.
    showRecipient = false,
    // Set of message_ids currently animating out (archive/delete). Items
    // in this set get .message-list-item--removing so they fade+collapse
    // before being dropped from props.messages on the next refresh (#4102).
    removingIds = null,
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
    const isRemoving = removingIds && removingIds.has(message.message_id)
    let itemClass = compact ? 'message-list-item message-list-item--compact' : 'message-list-item'
    if (isRemoving) itemClass += ' message-list-item--removing'
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
            {showRecipient ? (
              // On Sent: prefer the group when it's a group send, then
              // the recipient user, then a placeholder when we couldn't
              // recover that info (e.g., recipient deleted their copy
              // and the original `message` row is gone).
              message.for_usergroup && message.for_usergroup.node_id > 0 ? (
                <>To group: <LinkNode
                  id={message.for_usergroup.node_id}
                  display={message.for_usergroup.title}
                /></>
              ) : message.for_user && message.for_user.node_id > 0 ? (
                <>To: <LinkNode
                  id={message.for_user.node_id}
                  display={message.for_user.title}
                /></>
              ) : (
                <span className="message-list-recipient-unknown">Sent</span>
              )
            ) : (
              <LinkNode
                id={message.author_user.node_id}
                display={message.author_user.title}
              />
            )}
          </strong>
          <span className={timestampClass}>
            {formatTimestamp(message.timestamp)}
          </span>
        </div>

        {/* Redundant on Sent — the header above already names the group.
            Keep the existing "to group" line on Inbox so the recipient
            still sees which group they got the message in. */}
        {!showRecipient && message.for_usergroup && !compact && (
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
