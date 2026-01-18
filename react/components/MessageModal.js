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

  const handleSendAsChange = (e) => {
    const newValue = parseInt(e.target.value, 10)
    if (onSendAsChange) {
      onSendAsChange(newValue === currentUser.node_id ? null : newValue)
    }
  }

  // Build character count class
  const charCountClass = `message-modal-char-count${isOverLimit ? ' message-modal-char-count--over' : (isNearLimit ? ' message-modal-char-count--near' : '')}`

  return (
    <div className="message-modal-overlay">
      <div className="message-modal">
        {/* Header */}
        <div className="message-modal-header">
          <h3 className="message-modal-title">
            {replyTo ? (replyAll ? 'Reply All' : 'Reply') : 'New Message'}
          </h3>
          <button
            onClick={handleCancel}
            disabled={sending}
            className="message-modal-close"
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          {/* Send As selector - only show when user has access to bots */}
          {canSendAs && (
            <div className="message-modal-field">
              <label className="message-modal-label">
                Send as:
              </label>
              <div className="message-modal-sendas">
                <select
                  value={effectiveSendAs}
                  onChange={handleSendAsChange}
                  disabled={sending}
                  className="message-modal-sendas-select"
                >
                  {sendAsOptions.map(opt => (
                    <option key={opt.node_id} value={opt.node_id}>
                      {opt.title}{opt.isCurrentUser ? ' (yourself)' : ''}
                    </option>
                  ))}
                </select>
                {sendAsUser && sendAsUser !== currentUser?.node_id && (
                  <span className="message-modal-sendas-hint">
                    Sending as bot
                  </span>
                )}
              </div>
            </div>
          )}

          {/* Recipient */}
          <div className="message-modal-field">
            <label className="message-modal-label">
              To:
            </label>
            {replyTo ? (
              <div className="message-modal-recipient-display">
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
                        className="message-modal-toggle-btn"
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
                        className="message-modal-toggle-btn"
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
                  className="message-modal-input"
                />
                {/* Autocomplete suggestions dropdown */}
                {showSuggestions && suggestions.length > 0 && (
                  <div className="message-modal-autocomplete">
                    {suggestions.map((suggestion, index) => (
                      <div
                        key={suggestion.node_id}
                        onClick={() => handleSelectSuggestion(suggestion)}
                        onMouseEnter={() => setSelectedSuggestionIndex(index)}
                        className={`message-modal-suggestion${index === selectedSuggestionIndex ? ' message-modal-suggestion--selected' : ''}`}
                      >
                        {/* User/Group icon */}
                        <span className={`message-modal-suggestion-icon ${suggestion.type === 'usergroup' ? 'message-modal-suggestion-icon--group' : 'message-modal-suggestion-icon--user'}`}>
                          {suggestion.type === 'usergroup' ? '👥' : '👤'}
                        </span>
                        <span className={`message-modal-suggestion-title${suggestion.type === 'usergroup' ? ' message-modal-suggestion-title--group' : ''}`}>
                          {suggestion.title}
                        </span>
                        {suggestion.type === 'usergroup' && (
                          <span className="message-modal-suggestion-badge">
                            group
                          </span>
                        )}
                        {suggestion.alias && (
                          <span className="message-modal-suggestion-alias">
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
          <div className="message-modal-field">
            <label className="message-modal-label">
              Message:
            </label>
            <textarea
              id="message-modal-compose-textarea"
              ref={textareaRef}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              disabled={sending}
              rows={8}
              placeholder="Type your message here..."
              className={`message-modal-textarea${isOverLimit ? ' message-modal-textarea--error' : ''}`}
            />
            <div className={charCountClass}>
              {charCount} / {charLimit} characters
            </div>
          </div>

          {/* Error message */}
          {error && (
            <div className="message-modal-error">
              {error}
            </div>
          )}

          {/* Warning message */}
          {warning && (
            <div className="message-modal-warning">
              {warning}
            </div>
          )}

          {/* Buttons */}
          <div className="message-modal-actions">
            <button
              type="button"
              onClick={handleCancel}
              disabled={sending}
              className="message-modal-btn message-modal-btn--cancel"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={sending || isOverLimit || !message.trim()}
              className="message-modal-btn message-modal-btn--send"
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
