import React from 'react'
import LinkNode from './LinkNode'

/**
 * MessageModal - Modal dialog for composing messages
 *
 * Handles:
 * - New messages
 * - Replies to individual users
 * - Reply-all to usergroup messages
 * - Send-as-bot functionality for authorized users
 * - Character limit validation (512 chars)
 */
const MessageModal = ({
  isOpen,
  onClose,
  replyTo,
  onSend,
  initialReplyAll = false,
  initialMessage = '',
  // Send-as-bot props
  sendAsUser = null,
  accessibleBots = [],
  currentUser = null,
  onSendAsChange = null
}) => {
  const [message, setMessage] = React.useState('')
  const [recipient, setRecipient] = React.useState('')
  const [replyAll, setReplyAll] = React.useState(false)
  const [sending, setSending] = React.useState(false)
  const [error, setError] = React.useState(null)
  const [warning, setWarning] = React.useState(null)
  const textareaRef = React.useRef(null)

  // Initialize form when modal opens
  React.useEffect(() => {
    if (isOpen) {
      if (replyTo) {
        // Replying to an existing message
        setRecipient(replyTo.author_user.title)
        setReplyAll(initialReplyAll)
      } else {
        // New message
        setRecipient('')
        setReplyAll(false)
      }
      setMessage(initialMessage || '')
      setError(null)
      setWarning(null)
      setSending(false)  // Reset sending state when modal opens

      // Focus textarea after render
      setTimeout(() => {
        if (textareaRef.current) {
          textareaRef.current.focus()
          // If there's initial message text, move cursor to end
          if (initialMessage) {
            textareaRef.current.setSelectionRange(initialMessage.length, initialMessage.length)
          }
        }
      }, 100)
    }
  }, [isOpen, replyTo, initialReplyAll, initialMessage])

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!message.trim()) {
      setError('Message cannot be empty')
      return
    }

    if (message.length > 512) {
      setError('Message exceeds 512 character limit')
      return
    }

    if (!recipient.trim() && !replyTo) {
      setError('Please specify a recipient')
      return
    }

    setSending(true)
    setError(null)
    setWarning(null)

    try {
      let targetRecipient = recipient

      if (replyTo) {
        // Determine recipient based on reply type
        if (replyAll && replyTo.for_usergroup && replyTo.for_usergroup.title) {
          targetRecipient = replyTo.for_usergroup.title
        } else {
          targetRecipient = replyTo.author_user.title
        }
      }

      const result = await onSend(targetRecipient, message.trim())

      if (result === true || result?.success) {
        // Check for warnings (partial success)
        if (result?.warning) {
          setWarning(result.warning)
          setSending(false)
          // Don't close modal - let user see warning and decide to close
        } else {
          // Complete success - close modal
          onClose()
        }
      } else {
        setError('Failed to send message. Please try again.')
        setSending(false)
      }
    } catch (err) {
      setError(err.message || 'Failed to send message')
      setSending(false)
    }
  }

  const handleCancel = () => {
    if (!sending) {
      onClose()
    }
  }

  const toggleReplyAll = () => {
    setReplyAll(!replyAll)
  }

  if (!isOpen) return null

  const charCount = message.length
  const charLimit = 512
  const isOverLimit = charCount > charLimit
  const isNearLimit = charCount > charLimit * 0.9

  const canReplyAll = replyTo && replyTo.for_usergroup && replyTo.for_usergroup.node_id > 0

  // Determine if send-as selector should be shown
  // Show when user has access to bots and we have a way to change the selection
  const canSendAs = accessibleBots && accessibleBots.length > 0 && currentUser && onSendAsChange

  // Build the list of send-as options (current user + accessible bots)
  const sendAsOptions = canSendAs ? [
    { node_id: currentUser.node_id, title: currentUser.title, isCurrentUser: true },
    ...accessibleBots
  ] : []

  // Determine which user is currently selected for sending
  const effectiveSendAs = sendAsUser || (currentUser ? currentUser.node_id : null)
  const sendAsTitle = sendAsOptions.find(opt => opt.node_id === effectiveSendAs)?.title || currentUser?.title

  const handleSendAsChange = (e) => {
    const newValue = parseInt(e.target.value, 10)
    if (onSendAsChange) {
      onSendAsChange(newValue === currentUser.node_id ? null : newValue)
    }
  }

  return (
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
        zIndex: 10000,
        padding: '20px'
      }}
    >
      <div
        style={{
          backgroundColor: '#fff',
          borderRadius: '8px',
          padding: '24px',
          maxWidth: '600px',
          width: '100%',
          maxHeight: '90vh',
          overflow: 'auto',
          boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
          position: 'relative'
        }}
      >
        {/* Header */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          borderBottom: '2px solid #667eea',
          paddingBottom: '12px'
        }}>
          <h3 style={{ margin: 0, color: '#667eea', fontSize: '18px' }}>
            {replyTo ? (replyAll ? 'Reply All' : 'Reply') : 'New Message'}
          </h3>
          <button
            onClick={handleCancel}
            disabled={sending}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: sending ? 'not-allowed' : 'pointer',
              color: '#999',
              padding: '0',
              lineHeight: '1'
            }}
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          {/* Send As selector - only show when user has access to bots */}
          {canSendAs && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                marginBottom: '6px',
                fontSize: '13px',
                fontWeight: 'bold',
                color: '#333'
              }}>
                Send as:
              </label>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}>
                <select
                  value={effectiveSendAs}
                  onChange={handleSendAsChange}
                  disabled={sending}
                  style={{
                    padding: '8px 12px',
                    fontSize: '13px',
                    border: '1px solid #dee2e6',
                    borderRadius: '4px',
                    backgroundColor: '#fff',
                    cursor: sending ? 'not-allowed' : 'pointer',
                    minWidth: '200px'
                  }}
                >
                  {sendAsOptions.map(opt => (
                    <option key={opt.node_id} value={opt.node_id}>
                      {opt.title}{opt.isCurrentUser ? ' (yourself)' : ''}
                    </option>
                  ))}
                </select>
                {sendAsUser && sendAsUser !== currentUser?.node_id && (
                  <span style={{
                    fontSize: '11px',
                    color: '#667eea',
                    fontStyle: 'italic'
                  }}>
                    Sending as bot
                  </span>
                )}
              </div>
            </div>
          )}

          {/* Recipient */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{
              display: 'block',
              marginBottom: '6px',
              fontSize: '13px',
              fontWeight: 'bold',
              color: '#333'
            }}>
              To:
            </label>
            {replyTo ? (
              <div style={{
                padding: '8px 12px',
                backgroundColor: '#f8f9fa',
                border: '1px solid #dee2e6',
                borderRadius: '4px',
                fontSize: '13px'
              }}>
                {replyAll ? (
                  <>
                    <LinkNode
                      type="usergroup"
                      title={replyTo.for_usergroup.title}
                    />
                    {canReplyAll && (
                      <button
                        type="button"
                        onClick={toggleReplyAll}
                        disabled={sending}
                        style={{
                          marginLeft: '12px',
                          padding: '2px 8px',
                          fontSize: '11px',
                          backgroundColor: '#fff',
                          border: '1px solid #667eea',
                          borderRadius: '3px',
                          color: '#667eea',
                          cursor: 'pointer'
                        }}
                      >
                        Switch to individual reply
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    <LinkNode
                      type={replyTo.author_user.type}
                      title={replyTo.author_user.title}
                    />
                    {canReplyAll && (
                      <button
                        type="button"
                        onClick={toggleReplyAll}
                        disabled={sending}
                        style={{
                          marginLeft: '12px',
                          padding: '2px 8px',
                          fontSize: '11px',
                          backgroundColor: '#fff',
                          border: '1px solid #667eea',
                          borderRadius: '3px',
                          color: '#667eea',
                          cursor: 'pointer'
                        }}
                      >
                        Switch to reply all
                      </button>
                    )}
                  </>
                )}
              </div>
            ) : (
              <input
                type="text"
                value={recipient}
                onChange={(e) => setRecipient(e.target.value)}
                disabled={sending}
                placeholder="Username or usergroup name"
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  fontSize: '13px',
                  border: '1px solid #dee2e6',
                  borderRadius: '4px',
                  boxSizing: 'border-box'
                }}
              />
            )}
          </div>

          {/* Message */}
          <div style={{ marginBottom: '16px' }}>
            <label style={{
              display: 'block',
              marginBottom: '6px',
              fontSize: '13px',
              fontWeight: 'bold',
              color: '#333'
            }}>
              Message:
            </label>
            <textarea
              ref={textareaRef}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              disabled={sending}
              rows={8}
              placeholder="Type your message here..."
              style={{
                width: '100%',
                padding: '8px 12px',
                fontSize: '13px',
                border: `1px solid ${isOverLimit ? '#dc3545' : '#dee2e6'}`,
                borderRadius: '4px',
                boxSizing: 'border-box',
                fontFamily: 'inherit',
                resize: 'vertical'
              }}
            />
            <div style={{
              fontSize: '11px',
              color: isOverLimit ? '#dc3545' : (isNearLimit ? '#ffc107' : '#6c757d'),
              marginTop: '4px',
              textAlign: 'right'
            }}>
              {charCount} / {charLimit} characters
            </div>
          </div>

          {/* Error message */}
          {error && (
            <div style={{
              padding: '8px 12px',
              backgroundColor: '#f8d7da',
              border: '1px solid #f5c6cb',
              borderRadius: '4px',
              color: '#721c24',
              fontSize: '12px',
              marginBottom: '16px'
            }}>
              {error}
            </div>
          )}

          {/* Warning message */}
          {warning && (
            <div style={{
              padding: '8px 12px',
              backgroundColor: '#fff3cd',
              border: '1px solid #ffc107',
              borderRadius: '4px',
              color: '#856404',
              fontSize: '12px',
              marginBottom: '16px'
            }}>
              {warning}
            </div>
          )}

          {/* Buttons */}
          <div style={{
            display: 'flex',
            gap: '12px',
            justifyContent: 'flex-end'
          }}>
            <button
              type="button"
              onClick={handleCancel}
              disabled={sending}
              style={{
                padding: '8px 16px',
                fontSize: '13px',
                border: '1px solid #dee2e6',
                borderRadius: '4px',
                backgroundColor: '#fff',
                color: '#495057',
                cursor: sending ? 'not-allowed' : 'pointer'
              }}
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={sending || isOverLimit || !message.trim()}
              style={{
                padding: '8px 16px',
                fontSize: '13px',
                border: 'none',
                borderRadius: '4px',
                backgroundColor: (sending || isOverLimit || !message.trim()) ? '#e9ecef' : '#667eea',
                color: (sending || isOverLimit || !message.trim()) ? '#6c757d' : '#fff',
                cursor: (sending || isOverLimit || !message.trim()) ? 'not-allowed' : 'pointer',
                fontWeight: 'bold'
              }}
            >
              {sending ? 'Sending...' : 'Send Message'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default MessageModal
