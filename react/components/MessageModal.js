import React, { useState, useEffect, useCallback, useRef } from 'react'
import LinkNode from './LinkNode'

/**
 * MessageModal - Modal dialog for composing messages
 *
 * Handles:
 * - New messages with autocomplete recipient search
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
  const [message, setMessage] = useState('')
  const [recipient, setRecipient] = useState('')
  const [replyAll, setReplyAll] = useState(false)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState(null)
  const [warning, setWarning] = useState(null)
  const textareaRef = useRef(null)

  // Autocomplete state
  const [suggestions, setSuggestions] = useState([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [selectedSuggestionIndex, setSelectedSuggestionIndex] = useState(-1)
  const searchTimeoutRef = useRef(null)
  const recipientInputRef = useRef(null)

  // Initialize form when modal opens
  useEffect(() => {
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
      setSending(false)
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedSuggestionIndex(-1)

      // Focus recipient input for new messages, textarea for replies
      setTimeout(() => {
        if (!replyTo && recipientInputRef.current) {
          recipientInputRef.current.focus()
        } else if (textareaRef.current) {
          textareaRef.current.focus()
          if (initialMessage) {
            textareaRef.current.setSelectionRange(initialMessage.length, initialMessage.length)
          }
        }
      }, 100)
    }
  }, [isOpen, replyTo, initialReplyAll, initialMessage])

  // Autocomplete: search for message recipients
  const searchRecipients = useCallback(async (query) => {
    if (query.length < 2) {
      setSuggestions([])
      setShowSuggestions(false)
      return
    }

    try {
      const response = await fetch(
        `/api/node_search?q=${encodeURIComponent(query)}&scope=message_recipients&limit=10`
      )
      const data = await response.json()
      if (data.success && data.results) {
        setSuggestions(data.results)
        setShowSuggestions(data.results.length > 0)
        setSelectedSuggestionIndex(-1)
      }
    } catch (err) {
      console.error('Recipient search failed:', err)
      setSuggestions([])
    }
  }, [])

  // Handle recipient input change with debounced autocomplete
  const handleRecipientChange = useCallback((e) => {
    const newValue = e.target.value
    setRecipient(newValue)

    // Debounced autocomplete search
    if (searchTimeoutRef.current) {
      clearTimeout(searchTimeoutRef.current)
    }
    searchTimeoutRef.current = setTimeout(() => {
      searchRecipients(newValue.trim())
    }, 200)
  }, [searchRecipients])

  // Handle selecting a suggestion
  const handleSelectSuggestion = useCallback((suggestion) => {
    setRecipient(suggestion.title)
    setSuggestions([])
    setShowSuggestions(false)
    setSelectedSuggestionIndex(-1)
    // Focus textarea after selecting recipient
    setTimeout(() => {
      if (textareaRef.current) {
        textareaRef.current.focus()
      }
    }, 50)
  }, [])

  // Handle keyboard navigation in suggestions
  const handleRecipientKeyDown = useCallback((e) => {
    if (!showSuggestions || suggestions.length === 0) return

    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedSuggestionIndex(prev =>
        prev < suggestions.length - 1 ? prev + 1 : prev
      )
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedSuggestionIndex(prev => prev > 0 ? prev - 1 : -1)
    } else if (e.key === 'Enter' && selectedSuggestionIndex >= 0) {
      e.preventDefault()
      handleSelectSuggestion(suggestions[selectedSuggestionIndex])
    } else if (e.key === 'Escape') {
      setSuggestions([])
      setShowSuggestions(false)
      setSelectedSuggestionIndex(-1)
    }
  }, [showSuggestions, suggestions, selectedSuggestionIndex, handleSelectSuggestion])

  // Close suggestions when clicking outside
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (recipientInputRef.current && !recipientInputRef.current.parentElement.contains(e.target)) {
        setShowSuggestions(false)
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
      return () => document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

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
              <div style={{ position: 'relative' }}>
                <input
                  ref={recipientInputRef}
                  type="text"
                  value={recipient}
                  onChange={handleRecipientChange}
                  onKeyDown={handleRecipientKeyDown}
                  onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
                  disabled={sending}
                  placeholder="Username or usergroup name"
                  autoComplete="off"
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    fontSize: '13px',
                    border: '1px solid #dee2e6',
                    borderRadius: '4px',
                    boxSizing: 'border-box'
                  }}
                />
                {/* Autocomplete suggestions dropdown */}
                {showSuggestions && suggestions.length > 0 && (
                  <div style={{
                    position: 'absolute',
                    top: '100%',
                    left: 0,
                    right: 0,
                    backgroundColor: '#fff',
                    border: '1px solid #dee2e6',
                    borderTop: 'none',
                    borderRadius: '0 0 4px 4px',
                    boxShadow: '0 4px 8px rgba(0,0,0,0.1)',
                    maxHeight: '200px',
                    overflowY: 'auto',
                    zIndex: 100
                  }}>
                    {suggestions.map((suggestion, index) => (
                      <div
                        key={suggestion.node_id}
                        onClick={() => handleSelectSuggestion(suggestion)}
                        onMouseEnter={() => setSelectedSuggestionIndex(index)}
                        style={{
                          padding: '8px 12px',
                          cursor: 'pointer',
                          fontSize: '13px',
                          color: '#333',
                          borderBottom: index < suggestions.length - 1 ? '1px solid #eee' : 'none',
                          backgroundColor: index === selectedSuggestionIndex ? '#e8f4f8' : '#fff',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px'
                        }}
                      >
                        {/* User/Group icon */}
                        <span style={{
                          fontSize: '14px',
                          width: '20px',
                          textAlign: 'center',
                          color: suggestion.type === 'usergroup' ? '#4060b0' : '#507898'
                        }}>
                          {suggestion.type === 'usergroup' ? '👥' : '👤'}
                        </span>
                        <span style={{
                          fontWeight: suggestion.type === 'usergroup' ? 'bold' : 'normal',
                          flex: 1,
                          color: '#38495e'
                        }}>
                          {suggestion.title}
                        </span>
                        {suggestion.type === 'usergroup' && (
                          <span style={{ fontSize: '11px', color: '#4060b0' }}>
                            group
                          </span>
                        )}
                        {suggestion.alias && (
                          <span style={{ fontSize: '11px', color: '#507898', fontStyle: 'italic' }}>
                            via {suggestion.alias}
                          </span>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
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
