import React, { useState, useEffect, useRef, useCallback } from 'react'
import { FaTimes, FaComments, FaUsers, FaPaperPlane } from 'react-icons/fa'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * MobileChatModal - Full-screen mobile chat drawer
 *
 * Displays chatterbox and other users in a mobile-optimized drawer.
 * Has tabs for Chat (chatterbox) and Users (other users online).
 */

// Parse special message commands for display (/me, /whisper, /sing, /roll, etc.)
const parseMessageText = (msg) => {
  const text = msg.msgtext
  const author = msg.author_user

  // /me action
  if (text.match(/^\/me(\b)(.*)/i)) {
    const match = text.match(/^\/me(\b)(.*)/i)
    return (
      <em>
        <LinkNode type={author.type} title={author.title} />
        {match[1]}
        <ParseLinks text={match[2]} />
      </em>
    )
  }

  // /me's action
  if (text.match(/^\/me's\s(.*)/i)) {
    const match = text.match(/^\/me's\s(.*)/i)
    return (
      <em>
        <LinkNode type={author.type} title={author.title} />'s <ParseLinks text={match[1]} />
      </em>
    )
  }

  // /sing or /sings
  if (text.match(/^\/sings?\b\s?(.*)/i)) {
    const match = text.match(/^\/sings?\b\s?(.*)/i)
    return (
      <>
        {'<'}
        <LinkNode type={author.type} title={author.title} />
        {'> '}
        <em>♪ <ParseLinks text={match[1]} /> ♫</em>
      </>
    )
  }

  // /whisper
  if (text.match(/(^\/whisper)(.*)/i)) {
    const match = text.match(/(^\/whisper)(.*)/i)
    return (
      <small>
        {'<'}
        <LinkNode type={author.type} title={author.title} />
        {'> '}
        <ParseLinks text={match[2]} />
      </small>
    )
  }

  // /rolls
  if (text.match(/^\/rolls(.*)/i)) {
    const match = text.match(/^\/rolls(.*)/i)
    let rollText = match[1]
    if (text.match(/^\/rolls 1d2 (&rarr;|→) 1/i)) {
      rollText = ' flips a coin → heads'
    } else if (text.match(/^\/rolls 1d2 (&rarr;|→) 2/i)) {
      rollText = ' flips a coin → tails'
    } else {
      rollText = ' rolls' + rollText.replace(/&rarr;/g, '→')
    }
    return (
      <span className="mobile-chat-roll">
        <LinkNode type={author.type} title={author.title} />
        <ParseLinks text={rollText} />
      </span>
    )
  }

  // Default: <username> message
  return (
    <>
      {'<'}
      <LinkNode type={author.type} title={author.title} />
      {'> '}
      <ParseLinks text={text} />
    </>
  )
}

const MobileChatModal = ({
  isOpen,
  onClose,
  user,
  initialChatter = [],
  otherUsersData = null,
  currentRoom = 0,
  isGuest = false,
  isBorged = false,
  publicChatterOff = false,
  onChatterUpdate = null
}) => {
  const [activeTab, setActiveTab] = useState('chat')
  const [chatter, setChatter] = useState(initialChatter)
  const [message, setMessage] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState(null)
  const [chatterError, setChatterError] = useState(null)
  const [usersError, setUsersError] = useState(null)
  const [usersData, setUsersData] = useState(otherUsersData)
  const [loadingChatter, setLoadingChatter] = useState(false)
  const [loadingUsers, setLoadingUsers] = useState(false)
  const chatterEndRef = useRef(null)
  const inputRef = useRef(null)
  const pollInterval = useRef(null)

  // Stop polling helper
  const stopPolling = useCallback(() => {
    if (pollInterval.current) {
      clearInterval(pollInterval.current)
      pollInterval.current = null
    }
  }, [])

  // Scroll to bottom of chatter
  const scrollToBottom = useCallback(() => {
    if (chatterEndRef.current) {
      chatterEndRef.current.scrollIntoView({ behavior: 'smooth' })
    }
  }, [])

  // Load chatter messages
  const loadChatter = useCallback(async (initial = false) => {
    if (loadingChatter) return

    setLoadingChatter(true)
    try {
      const params = new URLSearchParams()
      params.append('limit', '50')
      if (currentRoom !== null) {
        params.append('room', currentRoom)
      }

      const response = await fetch(`/api/chatter/?${params}`, {
        credentials: 'include',
        headers: { 'X-Ajax-Idle': '1' }
      })

      if (!response.ok) {
        throw new Error(`Failed to load chatter (${response.status})`)
      }

      const data = await response.json()
      setChatter(data)
      setChatterError(null)
      // Notify parent of updated chatter count
      if (onChatterUpdate) {
        onChatterUpdate(data.length)
      }
      if (initial) {
        setTimeout(scrollToBottom, 100)
      }
    } catch (err) {
      console.error('Failed to load chatter:', err)
      setChatterError(err.message)
      // Stop polling on error to avoid hammering the API
      stopPolling()
    } finally {
      setLoadingChatter(false)
    }
  }, [currentRoom, loadingChatter, scrollToBottom, stopPolling, onChatterUpdate])

  // Load other users (one-time, no polling)
  const loadUsers = useCallback(async () => {
    if (loadingUsers) return

    setLoadingUsers(true)
    try {
      const response = await fetch('/api/chatroom/', {
        credentials: 'include',
        headers: { 'X-Ajax-Idle': '1' }
      })

      if (!response.ok) {
        throw new Error(`Failed to load users (${response.status})`)
      }

      const data = await response.json()
      setUsersData(data)
      setUsersError(null)
    } catch (err) {
      console.error('Failed to load users:', err)
      setUsersError(err.message)
    } finally {
      setLoadingUsers(false)
    }
  }, [loadingUsers])

  // Load data when modal opens
  useEffect(() => {
    if (isOpen) {
      // Reset errors when opening
      setChatterError(null)
      setUsersError(null)

      loadChatter(true)
      loadUsers()

      // Poll for new messages every 30 seconds (only if no error)
      pollInterval.current = setInterval(() => {
        // Don't poll if there's an error
        if (!chatterError) {
          loadChatter(false)
        }
      }, 30000)
    }

    return () => {
      stopPolling()
    }
  }, [isOpen]) // Intentionally minimal deps to avoid re-triggering

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

  // Send message
  const handleSend = async (e) => {
    e.preventDefault()
    if (!message.trim() || sending || isGuest) return

    setSending(true)
    setError(null)

    try {
      const response = await fetch('/api/chatter/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        credentials: 'same-origin',
        body: JSON.stringify({ message: message })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()

      if (data.success) {
        setMessage('')
        // Refresh chatter to show new message
        await loadChatter(false)
        scrollToBottom()
      } else {
        setError(data.error || 'Failed to send')
      }
    } catch (err) {
      setError('Failed to send message')
    } finally {
      setSending(false)
      if (inputRef.current) inputRef.current.focus()
    }
  }

  // Render user flags
  const renderFlags = (flags) => {
    if (!flags || flags.length === 0) return null
    return (
      <span className="mobile-chat-user-flags">
        {' ['}
        {flags.map((flag, idx) => (
          <React.Fragment key={idx}>
            {flag.type === 'god' && '@'}
            {flag.type === 'editor' && '$'}
            {flag.type === 'chanop' && '+'}
            {flag.type === 'borged' && 'Ø'}
            {flag.type === 'newuser' && flag.days}
          </React.Fragment>
        ))}
        {']'}
      </span>
    )
  }

  const userCount = usersData?.userCount || 0
  const chatCount = chatter?.length || 0

  if (!isOpen) return null

  return (
    <div className="mobile-modal-overlay">
      <div className="mobile-modal-drawer">
        {/* Header */}
        <div className="mobile-modal-header">
          <h2 className="mobile-modal-title">Chat</h2>
          <button
            type="button"
            onClick={onClose}
            className="mobile-modal-close-btn"
            aria-label="Close chat"
          >
            <FaTimes />
          </button>
        </div>

        {/* Tab bar */}
        <div className="mobile-modal-tab-bar">
          <button
            type="button"
            onClick={() => setActiveTab('chat')}
            className={`mobile-modal-tab${activeTab === 'chat' ? ' mobile-modal-tab--active' : ''}`}
          >
            <FaComments className="mobile-modal-tab-icon" />
            Chat
            {chatCount > 0 && (
              <span className="mobile-modal-badge">{chatCount > 99 ? '99+' : chatCount}</span>
            )}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('users')}
            className={`mobile-modal-tab${activeTab === 'users' ? ' mobile-modal-tab--active' : ''}`}
          >
            <FaUsers className="mobile-modal-tab-icon" />
            Users
            {userCount > 0 && (
              <span className="mobile-modal-badge">{userCount}</span>
            )}
          </button>
        </div>

        {/* Error display */}
        {error && (
          <div className="mobile-modal-error">{error}</div>
        )}

        {/* Content area */}
        <div className="mobile-chat-content">
          {activeTab === 'chat' ? (
            <>
              {/* Chatter messages */}
              <div className="mobile-chat-list">
                {chatterError ? (
                  <div className="mobile-modal-api-error">
                    <strong>Error loading chat:</strong> {chatterError}
                    <button
                      type="button"
                      onClick={() => {
                        setChatterError(null)
                        loadChatter(true)
                      }}
                      className="mobile-modal-retry-btn"
                    >
                      Retry
                    </button>
                  </div>
                ) : publicChatterOff ? (
                  <div className="mobile-chat-off">
                    You have chatter off. Use <code>/chatteron</code> to enable it.
                  </div>
                ) : loadingChatter && chatter.length === 0 ? (
                  <div className="mobile-modal-loading">Loading chat...</div>
                ) : chatter.length === 0 ? (
                  <div className="mobile-modal-empty">and all is quiet...</div>
                ) : (
                  [...chatter].reverse().map((msg) => (
                    <div key={msg.message_id} className="mobile-chat-message">
                      <div className="mobile-chat-message-content">
                        {parseMessageText(msg)}
                      </div>
                      <span className="mobile-chat-timestamp">
                        {new Date(msg.timestamp).toLocaleTimeString('en-US', {
                          hour: '2-digit',
                          minute: '2-digit',
                          hour12: false
                        })}
                      </span>
                    </div>
                  ))
                )}
                <div ref={chatterEndRef} />
              </div>

              {/* Message input */}
              {!isGuest && !isBorged && (
                <form onSubmit={handleSend} className="mobile-chat-input-form">
                  <input
                    ref={inputRef}
                    type="text"
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    placeholder="Type a message..."
                    disabled={sending}
                    maxLength={512}
                    className="mobile-chat-input"
                  />
                  <button
                    type="submit"
                    disabled={sending || !message.trim()}
                    className={`mobile-chat-send-btn${sending || !message.trim() ? ' mobile-chat-send-btn--disabled' : ''}`}
                  >
                    <FaPaperPlane />
                  </button>
                </form>
              )}

              {isGuest && (
                <div className="mobile-chat-guest-message">
                  Please log in to chat
                </div>
              )}

              {isBorged && (
                <div className="mobile-chat-borged-message">
                  You are borged and cannot chat
                </div>
              )}
            </>
          ) : (
            /* Users list */
            <div className="mobile-chat-users-list">
              {usersError ? (
                <div className="mobile-modal-api-error">
                  <strong>Error loading users:</strong> {usersError}
                  <button
                    type="button"
                    onClick={() => {
                      setUsersError(null)
                      loadUsers()
                    }}
                    className="mobile-modal-retry-btn"
                  >
                    Retry
                  </button>
                </div>
              ) : loadingUsers && !usersData ? (
                <div className="mobile-modal-loading">Loading users...</div>
              ) : !usersData || userCount === 0 ? (
                <div className="mobile-modal-empty">No one else is here</div>
              ) : (
                <>
                  {usersData.currentRoom && (
                    <div className="mobile-chat-room-header">
                      {usersData.currentRoom}
                    </div>
                  )}

                  {usersData.rooms?.map((room, roomIndex) => (
                    <div key={roomIndex} className="mobile-chat-room-section">
                      {room.title && usersData.rooms.length > 1 && (
                        <div className="mobile-chat-room-title">{room.title}</div>
                      )}
                      {room.users.map((u, userIndex) => (
                        <div
                          key={userIndex}
                          className={`mobile-chat-user-item${u.isCurrentUser ? ' mobile-chat-user-item--current' : ''}`}
                        >
                          <LinkNode
                            id={u.userId}
                            display={u.displayName}
                          />
                          {renderFlags(u.flags)}
                          {u.action && u.action.type === 'action' && (
                            <span className="mobile-chat-user-action">
                              {' '}is {u.action.verb} {u.action.noun}
                            </span>
                          )}
                        </div>
                      ))}
                    </div>
                  ))}
                </>
              )}
            </div>
          )}
        </div>

        {/* Footer link */}
        <div className="mobile-modal-footer">
          <a href="/title/Chatterlight" className="mobile-modal-footer-link">
            Mobile Chat
          </a>
        </div>
      </div>
    </div>
  )
}

export default MobileChatModal
