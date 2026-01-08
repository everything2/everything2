import React from 'react'
import NodeletContainer from '../NodeletContainer'
import { useChatterPolling } from '../../hooks/useChatterPolling'
import { useActivityDetection } from '../../hooks/useActivityDetection'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'
import MessageList from '../MessageList'
import MessageModal from '../MessageModal'

// Parse special message commands for display (/me, /whisper, /sing, /roll, etc.)
const parseMessageText = (msg) => {
  const text = msg.msgtext
  const author = msg.author_user

  // /me action → <em>username action</em>
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

  // /me's action → <em>username's action</em>
  if (text.match(/^\/me's\s(.*)/i)) {
    const match = text.match(/^\/me's\s(.*)/i)
    return (
      <em>
        <LinkNode type={author.type} title={author.title} />'s <ParseLinks text={match[1]} />
      </em>
    )
  }

  // /sing or /sings → <username> ♪ song ♫
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

  // /whisper → <small><username> whisper</small>
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

  // /death → <username> small-caps
  if (text.match(/(^\/death)(.*)/i)) {
    const match = text.match(/(^\/death)(.*)/i)
    return (
      <>
        {'<'}
        <LinkNode type={author.type} title={author.title} />
        {'> '}
        <span style={{ fontVariant: 'small-caps' }}>
          <ParseLinks text={match[2]} />
        </span>
      </>
    )
  }

  // /rolls → small-caps formatting
  if (text.match(/^\/rolls(.*)/i)) {
    const match = text.match(/^\/rolls(.*)/i)
    let rollText = match[1]

    // Special case: coin flip (check for HTML entity or actual arrow)
    if (text.match(/^\/rolls 1d2 (&rarr;|→) 1/i)) {
      rollText = ' flips a coin → heads'
    } else if (text.match(/^\/rolls 1d2 (&rarr;|→) 2/i)) {
      rollText = ' flips a coin → tails'
    } else {
      // Replace HTML entity with actual arrow character for dice rolls
      rollText = ' rolls' + rollText.replace(/&rarr;/g, '→')
    }

    return (
      <span style={{ fontVariant: 'small-caps' }}>
        <LinkNode type={author.type} title={author.title} />
        <ParseLinks text={rollText} />
      </span>
    )
  }

  // /fireball, /conflagrate, /immolate, /singe, /explode, /limn
  if (text.match(/^\/(fireball|conflagrate|immolate|singe|explode|limn)s?\s(.*)/i)) {
    const match = text.match(/^\/(fireball|conflagrate|immolate|singe|explode|limn)s?\s(.*)/i)
    const command = match[1].toLowerCase()
    const target = match[2]

    const fireballs = {
      fireball: 'BURSTS INTO FLAMES!!!',
      conflagrate: 'CONFLAGRATES!!!',
      immolate: 'IMMOLATES!!!',
      singe: 'is slightly singed. *cough*',
      explode: 'EXPLODES INTO PYROTECHNICS!!!',
      limn: 'IS LIMNED IN FLAMES!!!'
    }

    return (
      <>
        <span style={{ fontVariant: 'small-caps' }}>
          <LinkNode type={author.type} title={author.title} />
          {' fireballs '}
          {target}
        </span>
        ...<br />
        <em>
          <ParseLinks text={`[${target}]`} />
          {' '}
          {fireballs[command]}
        </em>
      </>
    )
  }

  // /sanctify
  if (text.match(/^\/sanctify?\s(.*)/i)) {
    const match = text.match(/^\/sanctify?\s(.*)/i)
    const target = match[1]
    return (
      <>
        <span style={{ fontVariant: 'small-caps' }}>
          <LinkNode type={author.type} title={author.title} />
          {' raises the hand of benediction...'}
        </span>
        <br />
        <em>
          <ParseLinks text={`[${target}]`} />
          {' has been SANCTIFIED!'}
        </em>
      </>
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

const Chatterbox = (props) => {
  const [message, setMessage] = React.useState('')
  const [sending, setSending] = React.useState(false)
  const [showCommands, setShowCommands] = React.useState(false)
  const [messageError, setMessageError] = React.useState(null)
  const [messageWarning, setMessageWarning] = React.useState(null)
  const [messageSuccess, setMessageSuccess] = React.useState(null)
  const [messageFading, setMessageFading] = React.useState(false)
  const [messageEntering, setMessageEntering] = React.useState(false)
  const [borgTimeRemaining, setBorgTimeRemaining] = React.useState(0)
  const inputRef = React.useRef(null)

  // Mini-messages state (when Messages nodelet not present)
  const [miniMessages, setMiniMessages] = React.useState(props.miniMessages || [])
  const [modalOpen, setModalOpen] = React.useState(false)
  const [replyingTo, setReplyingTo] = React.useState(null)
  const [isReplyAll, setIsReplyAll] = React.useState(false)
  const [deleteConfirmOpen, setDeleteConfirmOpen] = React.useState(false)
  const [messageToDelete, setMessageToDelete] = React.useState(null)

  // Activity detection for mini-messages polling
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const miniMessagesPollInterval = React.useRef(null)
  const miniMessagesMissedUpdate = React.useRef(false)
  const chatterContainerRef = React.useRef(null)

  // Poll at 45s when active, 2m when idle, stop when page not in focus
  // Skip polling when nodelet is collapsed or public chatter is off
  // Use initial messages from props to prevent redundant API call on page load
  const { chatter, loading, error, refresh } = useChatterPolling(
    45000,  // activeIntervalMs
    120000, // idleIntervalMs
    props.nodeletIsOpen && !props.publicChatterOff, // nodeletIsOpen (also disabled if chatter is off)
    props.currentRoom,   // currentRoom (for change detection)
    props.initialMessages // initialChatter (from backend)
  )

  // Auto-scroll to bottom when new chatter messages arrive
  React.useEffect(() => {
    if (chatterContainerRef.current && chatter.length > 0) {
      chatterContainerRef.current.scrollTop = chatterContainerRef.current.scrollHeight
    }
  }, [chatter])

  // Polling-based chatter display with fallback to legacy AJAX
  // The Messages component handles private messages when shown separately
  // This component provides the input interface and displays recent chatter

  // Calculate borg time remaining and update every second
  React.useEffect(() => {
    if (!props.borged) {
      setBorgTimeRemaining(0)
      return
    }

    const calculateTimeRemaining = () => {
      const currentTime = Math.floor(Date.now() / 1000) // Unix timestamp in seconds
      const timeElapsed = currentTime - props.borged
      const adjustedNum = (props.numborged || 1) * 2
      const cooldownPeriod = 300 + 60 * adjustedNum
      const remaining = Math.max(0, cooldownPeriod - timeElapsed)
      setBorgTimeRemaining(remaining)
      return remaining
    }

    // Calculate initial value
    calculateTimeRemaining()

    // Update every second
    const interval = setInterval(() => {
      const remaining = calculateTimeRemaining()
      // Clear interval when borg expires
      if (remaining === 0) {
        clearInterval(interval)
      }
    }, 1000)

    return () => clearInterval(interval)
  }, [props.borged, props.numborged])

  // Mini-messages handlers
  const loadMiniMessages = React.useCallback(async () => {
    if (!props.showMessagesInChatterbox) return

    try {
      const response = await fetch('/api/messages/?limit=5', {
        credentials: 'include',
        headers: {
          'X-Ajax-Idle': '1'
        }
      })

      if (!response.ok) {
        console.error('Failed to load mini-messages')
        return
      }

      const data = await response.json()
      setMiniMessages(data)
    } catch (err) {
      console.error('Error loading mini-messages:', err)
    }
  }, [props.showMessagesInChatterbox])

  const handleReply = (messageObj, replyAll = false) => {
    setReplyingTo(messageObj)
    setIsReplyAll(replyAll)
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

        // Refresh mini-messages list if sending to a usergroup (sender receives own message)
        if (data.poll_messages) {
          await loadMiniMessages()
        }

        // Return warning for partial success
        return { success: true, warning: warningMsg }
      }

      // Check for other errors (complete failures)
      if (data.errortext) {
        throw new Error(data.errortext)
      }

      // Refresh mini-messages list if sending to a usergroup (sender receives own message)
      if (data.poll_messages) {
        await loadMiniMessages()
      }

      return true
    } catch (err) {
      console.error('Failed to send message:', err)
      throw err
    }
  }

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
      setMiniMessages(miniMessages.filter(m => m.message_id !== messageId))
    } catch (err) {
      console.error('Archive error:', err)
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

      // Remove message from list
      setMiniMessages(miniMessages.filter(m => m.message_id !== messageId))
    } catch (err) {
      console.error('Unarchive error:', err)
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
      setMiniMessages(miniMessages.filter(m => m.message_id !== messageToDelete))
      setDeleteConfirmOpen(false)
      setMessageToDelete(null)
    } catch (err) {
      console.error('Delete error:', err)
      setDeleteConfirmOpen(false)
      setMessageToDelete(null)
    }
  }

  const cancelDelete = () => {
    setDeleteConfirmOpen(false)
    setMessageToDelete(null)
  }

  // Mini-messages polling effect - refresh every 2 minutes when active and nodelet is expanded
  React.useEffect(() => {
    if (!props.showMessagesInChatterbox) return

    const shouldPoll = isActive && isMultiTabActive && props.nodeletIsOpen

    if (shouldPoll) {
      miniMessagesPollInterval.current = setInterval(() => {
        loadMiniMessages()
      }, 120000) // 2 minutes
    } else {
      // If we're not polling because nodelet is collapsed, mark that we missed updates
      if (isActive && isMultiTabActive && !props.nodeletIsOpen) {
        miniMessagesMissedUpdate.current = true
      }

      if (miniMessagesPollInterval.current) {
        clearInterval(miniMessagesPollInterval.current)
        miniMessagesPollInterval.current = null
      }
    }

    return () => {
      if (miniMessagesPollInterval.current) {
        clearInterval(miniMessagesPollInterval.current)
        miniMessagesPollInterval.current = null
      }
    }
  }, [isActive, isMultiTabActive, props.nodeletIsOpen, props.showMessagesInChatterbox, loadMiniMessages])

  // Uncollapse detection: refresh immediately when nodelet is uncollapsed after missing updates
  React.useEffect(() => {
    if (props.nodeletIsOpen && miniMessagesMissedUpdate.current && props.showMessagesInChatterbox) {
      miniMessagesMissedUpdate.current = false
      loadMiniMessages()
    }
  }, [props.nodeletIsOpen, props.showMessagesInChatterbox, loadMiniMessages])

  // Focus refresh: immediately refresh when page becomes visible
  React.useEffect(() => {
    if (!props.showMessagesInChatterbox) return

    const handleVisibilityChange = () => {
      if (!document.hidden && isActive) {
        loadMiniMessages()
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isActive, props.showMessagesInChatterbox, loadMiniMessages])

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!message.trim() || sending) {
      return
    }

    setSending(true)

    try {
      // Handle /clearchatter command (admin-only)
      if (message.trim() === '/clearchatter') {
        const response = await fetch('/api/chatter/clear_all', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          credentials: 'same-origin'
        })

        if (!response.ok) {
          if (response.status === 403) {
            console.warn('Clear chatter requires admin access')
          } else {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`)
          }
        } else {
          const data = await response.json()
          console.log(`Cleared ${data.deleted} chatter messages`)
          setMessage('')
          refresh()
        }
        setSending(false)
        // Restore focus to input after render
        setTimeout(() => {
          if (inputRef.current) inputRef.current.focus()
        }, 0)
        return
      }

      // Use chatter API for all messages (now handles commands via processMessageCommand)
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
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()

      if (data.success) {
        setMessage('')
        setMessageError(null)

        // If command needs immediate message poll (e.g., /help), trigger it
        if (data.poll_messages) {
          loadMiniMessages()
        }

        // Check for warnings (partial usergroup blocks)
        if (data.warning) {
          setMessageWarning(data.warning)
          setMessageFading(false)
          setMessageEntering(true)
          // Fade in quickly
          setTimeout(() => setMessageEntering(false), 150)
          // Auto-clear warning with fade-out after 5 seconds
          setTimeout(() => {
            setMessageFading(true)
            setTimeout(() => {
              setMessageWarning(null)
              setMessageFading(false)
            }, 300)
          }, 5000)
        } else {
          setMessageWarning(null)
        }

        // Show success message for /msg, /help, and /macro commands (unless there's a warning)
        // since there's no visible feedback in the chatter feed for these
        if (!data.warning) {
          const isPrivateMessage = /^\/(msg|message|whisper|small)\s/.test(message.trim())
          const isHelpCommand = /^\/help\s/.test(message.trim())
          const isMacroCommand = /^\/macro\s/.test(message.trim())
          if (isPrivateMessage || isHelpCommand || isMacroCommand) {
            // Use info from server if available (e.g., macro results), otherwise default message
            const successMsg = data.info || (isHelpCommand ? 'Help sent to your messages' : 'Message sent')
            setMessageSuccess(successMsg)
            setMessageFading(false)
            setMessageEntering(true)
            // Fade in quickly
            setTimeout(() => setMessageEntering(false), 150)
            // Auto-clear success with fade-out after 3 seconds
            setTimeout(() => {
              setMessageFading(true)
              setTimeout(() => {
                setMessageSuccess(null)
                setMessageFading(false)
              }, 300)
            }, 3000)
          } else {
            // No success message - user sees immediate feedback in chatter
            setMessageSuccess(null)
          }
        } else {
          // Warning already shows feedback - don't show success
          setMessageSuccess(null)
        }

        // Refresh chatter display to show new message
        refresh()
      } else {
        // Message was not posted - show error to user and clear input
        setMessageError(data.error || 'Message not posted')
        setMessageWarning(null)
        setMessage('')
        setMessageFading(false)
        setMessageEntering(true)
        // Fade in quickly
        setTimeout(() => setMessageEntering(false), 150)
        // Auto-clear error with fade-out after 5 seconds
        setTimeout(() => {
          setMessageFading(true) // Start fade
          setTimeout(() => {
            setMessageError(null) // Remove after fade
            setMessageFading(false)
          }, 300) // Match CSS transition duration
        }, 5000)
      }
    } catch (err) {
      console.error('Failed to send message:', err)
      setMessageError('Failed to send message')
      setMessage('')
      setMessageFading(false)
      setMessageEntering(true)
      // Fade in quickly
      setTimeout(() => setMessageEntering(false), 150)
      setTimeout(() => {
        setMessageFading(true) // Start fade
        setTimeout(() => {
          setMessageError(null) // Remove after fade
          setMessageFading(false)
        }, 300) // Match CSS transition duration
      }, 5000)
    } finally {
      setSending(false)
      // Restore focus to input so user can continue chatting
      setTimeout(() => {
        if (inputRef.current) inputRef.current.focus()
      }, 0)
    }
  }

  // Check if user is borged (suspended from chat)
  const isBorged = props.borged || false
  const isChatSuspended = props.chatSuspended || false
  const isGuest = props.isGuest || false
  const isEditor = props.user?.editor || false
  const isAdmin = props.user?.admin || false
  const isChanop = props.user?.chanop || false
  const hasEasterEggs = (props.easterEggs || 0) > 0

  // Get available commands based on user permissions
  const getAvailableCommands = () => {
    const commands = [
      { cmd: '/msg or /tell <user> <text>', desc: 'Send a private message (replace spaces with underscores in usernames)' },
      { cmd: '/msg? <user> <text>', desc: 'Send online-only message (only sent to online members, unless they have "get online-only messages while offline" enabled in Settings)' },
      { cmd: '/me <action>', desc: 'Perform an action (e.g., "/me waves")' },
      { cmd: '/roll <dice>', desc: 'Roll dice (e.g., "/roll 2d6")' },
      { cmd: '/flip', desc: 'Flip a coin (same as /roll 1d2)' },
      { cmd: '/ignore <user>', desc: 'Ignore messages from a user (replace spaces with underscores)' },
      { cmd: '/unignore <user>', desc: 'Stop ignoring a user (replace spaces with underscores)' },
      { cmd: '/chatteroff', desc: 'Hide public chatter' },
      { cmd: '/chatteron', desc: 'Show public chatter' }
    ]

    // Editor+ commands (beta features)
    if (isEditor || isAdmin) {
      commands.push(
        { cmd: '/macro <name>', desc: 'Use a saved macro (beta)', restricted: true }
      )
    }

    // Easter Eggs commands (require Easter Eggs or admin)
    if (hasEasterEggs || isAdmin) {
      commands.push(
        { cmd: '/fireball <user>', desc: 'Award GP to a user (requires Easter Eggs, replace spaces with underscores)', restricted: true },
        { cmd: '/sanctify <user>', desc: 'Award GP to a user (requires Easter Eggs, replace spaces with underscores)', restricted: true }
      )
    }

    // Chanop and admin commands
    if (isChanop || isAdmin) {
      commands.push(
        { cmd: '/borg <user> [reason]', desc: 'Suspend user from chat (replace spaces with underscores)', restricted: true },
        { cmd: '/drag <user>', desc: 'Move user to your room (replace spaces with underscores)', restricted: true },
        { cmd: '/topic <text>', desc: 'Set room topic', restricted: true }
      )
    }

    // Additional admin-only commands
    if (isAdmin) {
      commands.push(
        { cmd: '/clearchatter', desc: 'Clear all chatter in current room', restricted: true },
        { cmd: '/sayas <user> <text>', desc: 'Speak as another user (replace spaces with underscores)', restricted: true },
        { cmd: '/invite <user>', desc: 'Invite user to room (replace spaces with underscores)', restricted: true }
      )
    }

    return commands
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Chatterbox"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {/* Room topic or chat location display */}
      {props.roomName && (
        <div style={{
          marginBottom: '12px',
          padding: '8px',
          backgroundColor: '#fffbea',
          border: '1px solid #ffd700',
          borderRadius: '4px',
          fontSize: '11px',
          color: '#333'
        }}>
          {props.roomTopic ? (
            <>
              <strong style={{ color: '#b8860b' }}>{props.roomName}:</strong>{' '}
              <ParseLinks text={props.roomTopic} />
            </>
          ) : (
            <em>You are now chatting {props.roomName === 'outside' ? 'outside' : `in ${props.roomName}`}</em>
          )}
        </div>
      )}

      {/* Private messages section - only shown if Messages nodelet not separately displayed */}
      {props.showMessagesInChatterbox && (
        <div id="chatterbox_messages" style={{
          marginBottom: '12px',
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '4px',
          padding: '8px'
        }}>
          <div style={{
            fontSize: '11px',
            fontWeight: 'bold',
            marginBottom: '8px',
            paddingBottom: '6px',
            borderBottom: '1px solid #dee2e6',
            color: '#495057',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center'
          }}>
            <span>Recent Messages</span>
            <a
              href="/title/Message+Inbox"
              style={{
                fontSize: '10px',
                color: '#667eea',
                textDecoration: 'none'
              }}
            >
              view all →
            </a>
          </div>
          <MessageList
            messages={miniMessages}
            onReply={handleReply}
            onReplyAll={handleReply}
            onArchive={handleArchive}
            onUnarchive={handleUnarchive}
            onDelete={handleDelete}
            compact={false}
            chatOrder={true}
            limit={5}
            showActions={{
              reply: true,
              replyAll: true,
              archive: true,
              unarchive: true,
              delete: true
            }}
          />
        </div>
      )}

      {/* Chatter display - polling-based */}
      <div id="chatterbox_chatter" style={{
        marginBottom: '12px',
        minHeight: chatter.length > 0 ? '200px' : 'auto',  // Only use min height when there are messages
        maxHeight: '400px',
        overflowY: 'auto'
      }}>
        {props.publicChatterOff ? (
          <div style={{
            fontSize: '12px',
            color: '#856404',
            backgroundColor: '#fff3cd',
            border: '1px solid #ffc107',
            borderRadius: '4px',
            padding: '12px',
            textAlign: 'center'
          }}>
            You have chatter off. Use <code>/chatteron</code> to enable it.
          </div>
        ) : (
          <>
            {loading && chatter.length === 0 && (
              <div style={{ fontSize: '11px', color: '#999', padding: '8px', textAlign: 'center' }}>
                Loading chatter...
              </div>
            )}

            {error && (
              <div style={{ fontSize: '11px', color: '#dc3545', padding: '8px' }}>
                Error loading chatter: {error}
              </div>
            )}

            {chatter.length === 0 && !loading && !error && (
              <div style={{ fontSize: '11px', color: '#999', padding: '8px', fontStyle: 'italic' }}>
                and all is quiet...
              </div>
            )}

            {chatter.length > 0 && (
              <div
                ref={chatterContainerRef}
                style={{
                  fontSize: '11px',
                  lineHeight: '1.4',
                  maxHeight: '400px',
                  overflowY: 'auto'
                }}
              >
                {[...chatter].reverse().map((msg) => (
                  <div key={msg.message_id} style={{ padding: '4px 8px', borderBottom: '1px solid #f0f0f0' }}>
                    {parseMessageText(msg)}
                    <span style={{ color: '#999', fontSize: '10px', marginLeft: '8px' }}>
                      {new Date(msg.timestamp).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false })}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>

      {/* Message input form */}
      {!isGuest && (
        <div style={{
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '4px',
          padding: '8px'
        }}>
          <form onSubmit={handleSubmit} id="chatterbox_input_form">
            {isBorged && borgTimeRemaining > 0 && (
              <div style={{
                fontSize: '12px',
                color: '#dc3545',
                fontWeight: 'bold',
                marginBottom: '6px',
                textAlign: 'center',
                padding: '8px',
                backgroundColor: '#fff3cd',
                border: '1px solid #ffc107',
                borderRadius: '4px'
              }}>
                You are borged! {Math.floor(borgTimeRemaining / 60)}:{String(borgTimeRemaining % 60).padStart(2, '0')}
              </div>
            )}

            {isChatSuspended && !isBorged && (
              <div style={{
                fontSize: '11px',
                color: '#dc3545',
                marginBottom: '6px'
              }}>
                You are currently suspended from public chat, but you can /msg other users.
              </div>
            )}

            {/* Hide input entirely when borged, show only countdown */}
            {!isBorged && (
              <div style={{ display: 'flex', gap: '6px' }}>
                <input
                  ref={inputRef}
                  type="text"
                  id="message"
                  name="message"
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  disabled={sending}
                  maxLength={512}
                  autoComplete="off"
                  style={{
                    flex: 1,
                    padding: '4px 8px',
                    fontSize: '12px',
                    borderRadius: '3px',
                    border: '1px solid #dee2e6',
                    backgroundColor: '#fff'
                  }}
                  placeholder="Type a message..."
                />
                <button
                  type="submit"
                  id="message_send"
                  disabled={sending || !message.trim()}
                  style={{
                    padding: '4px 12px',
                    fontSize: '12px',
                    border: '1px solid #dee2e6',
                    borderRadius: '3px',
                    backgroundColor: !message.trim() ? '#e9ecef' : '#fff',
                    cursor: !message.trim() ? 'not-allowed' : 'pointer'
                  }}
                >
                  talk
                </button>
              </div>
            )}

            {props.showHelp && (
              <div style={{
                fontSize: '11px',
                textAlign: 'center',
                marginTop: '8px',
                color: '#6c757d'
              }}>
                <a href="/title/Chatterbox" style={{ textDecoration: 'none', color: '#667eea' }}>
                  How does this work?
                </a>
                {' | '}
                <a href="/title/Chatterlight" style={{ textDecoration: 'none', color: '#667eea' }}>
                  Chatterlight
                </a>
              </div>
            )}
          </form>
        </div>
      )}

      {isGuest && (
        <div style={{
          padding: '12px',
          fontSize: '12px',
          color: '#999',
          fontStyle: 'italic',
          textAlign: 'center'
        }}>
          Please log in to use the chatterbox
        </div>
      )}

      {/* Commands Help Link + Message Container - Fixed height to prevent layout shift */}
      {!isGuest && (
        <div style={{
          position: 'relative',
          minHeight: '40px',
          marginTop: '8px',
          textAlign: 'center'
        }}>
          {/* Error/Success Messages - Absolutely positioned to overlay the link */}
          {messageError && (
            <div style={{
              position: 'absolute',
              top: 0,
              left: '12px',
              right: '12px',
              padding: '8px 12px',
              backgroundColor: '#fee',
              border: '1px solid #fcc',
              borderRadius: '4px',
              color: '#c33',
              fontSize: '12px',
              textAlign: 'center',
              opacity: messageFading ? 0 : (messageEntering ? 0 : 1),
              transition: messageFading ? 'opacity 0.3s ease-out' : 'opacity 0.15s ease-in',
              zIndex: 1
            }}>
              {messageError}
            </div>
          )}

          {messageSuccess && (
            <div style={{
              position: 'absolute',
              top: 0,
              left: '12px',
              right: '12px',
              padding: '8px 12px',
              backgroundColor: '#d4edda',
              border: '1px solid #c3e6cb',
              borderRadius: '4px',
              color: '#155724',
              fontSize: '12px',
              textAlign: 'center',
              opacity: messageFading ? 0 : (messageEntering ? 0 : 1),
              transition: messageFading ? 'opacity 0.3s ease-out' : 'opacity 0.15s ease-in',
              zIndex: 1
            }}>
              {messageSuccess}
            </div>
          )}

          {messageWarning && (
            <div style={{
              position: 'absolute',
              top: 0,
              left: '12px',
              right: '12px',
              padding: '8px 12px',
              backgroundColor: '#fff3cd',
              border: '1px solid #ffc107',
              borderRadius: '4px',
              color: '#856404',
              fontSize: '12px',
              textAlign: 'center',
              opacity: messageFading ? 0 : (messageEntering ? 0 : 1),
              transition: messageFading ? 'opacity 0.3s ease-out' : 'opacity 0.15s ease-in',
              zIndex: 1
            }}>
              {messageWarning}
            </div>
          )}

          {/* Chat Commands Link - In normal flow beneath messages */}
          <button
            onClick={() => setShowCommands(true)}
            style={{
              background: 'none',
              border: 'none',
              color: '#667eea',
              cursor: 'pointer',
              textDecoration: 'underline',
              fontSize: '11px',
              padding: '2px 4px',
              marginTop: '0'
            }}
          >
            Chat Commands
          </button>
        </div>
      )}

      {/* Commands Modal */}
      {showCommands && (
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
          onClick={() => setShowCommands(false)}
        >
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '8px',
              padding: '20px',
              maxWidth: '900px',
              maxHeight: '90vh',
              overflow: 'auto',
              boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
              position: 'relative',
              width: '90%'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '16px',
              borderBottom: '2px solid #667eea',
              paddingBottom: '8px'
            }}>
              <h3 style={{ margin: 0, color: '#667eea', fontSize: '18px' }}>
                Chat Commands
              </h3>
              <button
                onClick={() => setShowCommands(false)}
                style={{
                  background: 'none',
                  border: 'none',
                  fontSize: '24px',
                  cursor: 'pointer',
                  color: '#999',
                  padding: '0',
                  lineHeight: '1'
                }}
              >
                ×
              </button>
            </div>

            <div style={{ fontSize: '12px', lineHeight: '1.6' }}>
              {getAvailableCommands().map((command, index) => (
                <div
                  key={index}
                  style={{
                    marginBottom: '12px',
                    paddingBottom: '12px',
                    borderBottom: index < getAvailableCommands().length - 1 ? '1px solid #eee' : 'none'
                  }}
                >
                  <div style={{
                    fontFamily: 'monospace',
                    fontWeight: 'bold',
                    color: command.restricted ? '#dc3545' : '#667eea',
                    marginBottom: '4px'
                  }}>
                    {command.cmd}
                    {command.restricted && (
                      <span style={{
                        fontSize: '10px',
                        marginLeft: '8px',
                        padding: '2px 6px',
                        backgroundColor: '#dc3545',
                        color: '#fff',
                        borderRadius: '3px'
                      }}>
                        {isAdmin ? 'ADMIN' : 'CHANOP'}
                      </span>
                    )}
                  </div>
                  <div style={{ color: '#666' }}>
                    {command.desc}
                  </div>
                </div>
              ))}
            </div>

            <div style={{
              marginTop: '16px',
              paddingTop: '16px',
              borderTop: '2px solid #eee',
              fontSize: '11px',
              color: '#999',
              textAlign: 'center'
            }}>
              <p style={{ margin: '4px 0' }}>
                Showing {getAvailableCommands().length} available commands
              </p>
              {(isChanop || isAdmin) && (
                <p style={{ margin: '4px 0', color: '#dc3545' }}>
                  You have elevated privileges - use responsibly
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Message composition modal for mini-messages */}
      {props.showMessagesInChatterbox && (
        <MessageModal
          isOpen={modalOpen}
          onClose={() => setModalOpen(false)}
          replyTo={replyingTo}
          onSend={handleSendMessage}
          initialReplyAll={isReplyAll}
        />
      )}

      {/* Delete confirmation modal for mini-messages */}
      {props.showMessagesInChatterbox && deleteConfirmOpen && (
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

export default Chatterbox
