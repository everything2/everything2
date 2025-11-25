import React from 'react'
import NodeletContainer from '../NodeletContainer'
import { useChatterPolling } from '../../hooks/useChatterPolling'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

// Parse special message commands for display (mimics legacy showchatter behavior)
const parseMessageText = (msg) => {
  const text = msg.msgtext
  const author = msg.author_user

  // /me action → <em>username action</em>
  if (text.match(/^\/me(\b)(.*)/i)) {
    const match = text.match(/^\/me(\b)(.*)/i)
    return (
      <em>
        <LinkNode type={author.type} title={author.title} />
        {match[1]}{match[2]}
      </em>
    )
  }

  // /me's action → <em>username's action</em>
  if (text.match(/^\/me's\s(.*)/i)) {
    const match = text.match(/^\/me's\s(.*)/i)
    return (
      <em>
        <LinkNode type={author.type} title={author.title} />'s {match[1]}
      </em>
    )
  }

  // /sing or /sings → <username> ♪ song ♫
  if (text.match(/^\/sings?\b\s?(.*)/i)) {
    const match = text.match(/^\/sings?\b\s?(.*)/i)
    const notes = ['♫', '♪', '♫♪', '♪♫']
    const randomNote1 = notes[Math.floor(Math.random() * notes.length)]
    const randomNote2 = notes[Math.floor(Math.random() * notes.length)]
    return (
      <>
        {'<'}
        <LinkNode type={author.type} title={author.title} />
        {'> '}
        <em>{randomNote1} {match[1]} {randomNote2}</em>
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
        {match[2]}
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
        <span style={{ fontVariant: 'small-caps' }}>{match[2]}</span>
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
      rollText = ' rolls' + rollText
    }

    return (
      <span style={{ fontVariant: 'small-caps' }}>
        <LinkNode type={author.type} title={author.title} />
        <span dangerouslySetInnerHTML={{ __html: rollText }} />
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
      <span dangerouslySetInnerHTML={{ __html: text }} />
    </>
  )
}

const Chatterbox = (props) => {
  const [message, setMessage] = React.useState('')
  const [sending, setSending] = React.useState(false)
  const [showCommands, setShowCommands] = React.useState(false)
  const inputRef = React.useRef(null)
  // Poll at 45s when active, 2m when idle, stop when page not in focus
  // Skip polling when nodelet is collapsed, refresh on room change
  // Use initial messages from props to prevent redundant API call on page load
  const { chatter, loading, error, refresh } = useChatterPolling(
    45000,  // activeIntervalMs
    120000, // idleIntervalMs
    props.nodeletIsOpen, // nodeletIsOpen
    props.currentRoom,   // currentRoom (for change detection)
    props.initialMessages // initialChatter (from backend)
  )

  // Polling-based chatter display with fallback to legacy AJAX
  // The Messages component handles private messages when shown separately
  // This component provides the input interface and displays recent chatter

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
        // Refresh chatter display to show new message
        refresh()
      } else {
        // Message was not posted (duplicate, suspension, etc.)
        console.warn('Message not posted:', data.error)
      }
    } catch (err) {
      console.error('Failed to send message:', err)
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

  // Get available commands based on user permissions
  const getAvailableCommands = () => {
    const commands = [
      { cmd: '/msg or /tell <user> <text>', desc: 'Send a private message (replace spaces with underscores in usernames)' },
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

    // Chanop and admin commands
    if (isChanop || isAdmin) {
      commands.push(
        { cmd: '/fireball <user>', desc: 'Award GP to a user (replace spaces with underscores)', restricted: true },
        { cmd: '/sanctify <user>', desc: 'Award GP to a user (replace spaces with underscores)', restricted: true },
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
        <div id="chatterbox_messages" style={{ marginBottom: '12px' }}>
          {/* This div will be populated by legacy code or Messages component */}
        </div>
      )}

      {/* Chatter display - polling-based */}
      <div id="chatterbox_chatter" style={{ marginBottom: '12px' }}>
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
          <div style={{
            maxHeight: '400px',
            overflowY: 'auto',
            fontSize: '11px',
            lineHeight: '1.4'
          }}>
            {[...chatter].reverse().map((msg) => (
              <div key={msg.message_id} style={{ padding: '4px 8px', borderBottom: '1px solid #f0f0f0' }}>
                {parseMessageText(msg)}
                <span style={{ color: '#999', fontSize: '10px', marginLeft: '8px' }}>
                  {new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                </span>
              </div>
            ))}
          </div>
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
            {isBorged && (
              <div style={{
                fontSize: '11px',
                color: '#dc3545',
                marginBottom: '6px'
              }}>
                You're borged, so you can't talk right now.
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

            <div style={{ display: 'flex', gap: '6px' }}>
              <input
                ref={inputRef}
                type="text"
                id="message"
                name="message"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                disabled={isBorged || sending}
                maxLength={512}
                style={{
                  flex: 1,
                  padding: '4px 8px',
                  fontSize: '12px',
                  borderRadius: '3px',
                  border: '1px solid #dee2e6',
                  backgroundColor: isBorged ? '#e9ecef' : '#fff'
                }}
                placeholder={isBorged ? "You're borged" : "Type a message..."}
              />
              <button
                type="submit"
                id="message_send"
                disabled={isBorged || sending || !message.trim()}
                style={{
                  padding: '4px 12px',
                  fontSize: '12px',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  backgroundColor: (isBorged || !message.trim()) ? '#e9ecef' : '#fff',
                  cursor: (isBorged || !message.trim()) ? 'not-allowed' : 'pointer'
                }}
              >
                {isBorged ? 'erase' : 'talk'}
              </button>
            </div>

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

      {/* Commands Help Link */}
      {!isGuest && (
        <div style={{
          marginTop: '8px',
          textAlign: 'center',
          fontSize: '11px'
        }}>
          <button
            onClick={() => setShowCommands(true)}
            style={{
              background: 'none',
              border: 'none',
              color: '#667eea',
              cursor: 'pointer',
              textDecoration: 'underline',
              fontSize: '11px',
              padding: '2px 4px'
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
    </NodeletContainer>
  )
}

export default Chatterbox
