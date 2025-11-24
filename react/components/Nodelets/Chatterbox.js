import React from 'react'
import NodeletContainer from '../NodeletContainer'
import { useChatterPolling } from '../../hooks/useChatterPolling'
import LinkNode from '../LinkNode'

const Chatterbox = (props) => {
  const [message, setMessage] = React.useState('')
  const [sending, setSending] = React.useState(false)
  const { chatter, loading, error, refresh } = useChatterPolling(3000)

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
      // Use new chatter API endpoint
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
    }
  }

  // Check if user is borged (suspended from chat)
  const isBorged = props.borged || false
  const isChatSuspended = props.chatSuspended || false
  const isGuest = props.isGuest || false

  return (
    <NodeletContainer
      title="Chatterbox"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
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

        {chatter.length === 0 && !loading && (
          <div style={{ fontSize: '11px', color: '#999', padding: '8px', fontStyle: 'italic' }}>
            No recent chatter
          </div>
        )}

        {chatter.length > 0 && (
          <div style={{
            maxHeight: '400px',
            overflowY: 'auto',
            fontSize: '11px',
            lineHeight: '1.4'
          }}>
            {chatter.map((msg) => (
              <div key={msg.message_id} style={{ padding: '4px 8px', borderBottom: '1px solid #f0f0f0' }}>
                <span style={{ fontWeight: 'bold' }}>
                  <LinkNode node={msg.author_user} />
                </span>
                {': '}
                <span dangerouslySetInnerHTML={{ __html: msg.msgtext }} />
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

          {/* Room topic display */}
          {props.roomTopic && (
            <div style={{
              marginTop: '8px',
              padding: '6px',
              backgroundColor: '#fff',
              border: '1px solid #dee2e6',
              borderRadius: '3px',
              fontSize: '11px'
            }}>
              <strong>Topic:</strong> {props.roomTopic}
            </div>
          )}
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
    </NodeletContainer>
  )
}

export default Chatterbox
