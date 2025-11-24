import React from 'react'
import NodeletContainer from '../NodeletContainer'
import ParseLinks from '../ParseLinks'
import LinkNode from '../LinkNode'

const Messages = (props) => {
  const [messages, setMessages] = React.useState(props.initialMessages || [])
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState(null)
  const [showArchived, setShowArchived] = React.useState(false)

  if (!messages) {
    return (
      <NodeletContainer
        title="Messages"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
          No messages available
        </p>
      </NodeletContainer>
    )
  }

  const loadMessages = async (archived = false) => {
    setLoading(true)
    setError(null)

    try {
      const archiveParam = archived ? '&archive=1' : ''
      const response = await fetch(`/api/messages/?limit=10${archiveParam}`, {
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to load messages')
      }

      const data = await response.json()
      setMessages(data)
      setShowArchived(archived)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
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
      setMessages(messages.filter(m => m.message_id !== messageId))
    } catch (err) {
      setError(err.message)
    }
  }

  const handleDelete = async (messageId) => {
    try {
      const response = await fetch(`/api/messages/${messageId}/action/delete`, {
        method: 'POST',
        credentials: 'include'
      })

      if (!response.ok) {
        throw new Error('Failed to delete message')
      }

      // Remove message from list
      setMessages(messages.filter(m => m.message_id !== messageId))
    } catch (err) {
      setError(err.message)
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
      setMessages(messages.filter(m => m.message_id !== messageId))
    } catch (err) {
      setError(err.message)
    }
  }

  const formatTimestamp = (timestamp) => {
    const date = new Date(timestamp)
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const renderMessage = (message) => {
    return (
      <div
        key={message.message_id}
        id={`message_${message.message_id}`}
        style={{
          backgroundColor: '#f8f9fa',
          border: '1px solid #dee2e6',
          borderRadius: '4px',
          padding: '8px',
          marginBottom: '8px',
          fontSize: '12px'
        }}
      >
        <div style={{ marginBottom: '4px' }}>
          <strong>
            <LinkNode
              id={message.author_user.node_id}
              display={message.author_user.title}
            />
          </strong>
          <span style={{ color: '#6c757d', fontSize: '11px', marginLeft: '8px' }}>
            {formatTimestamp(message.timestamp)}
          </span>
        </div>

        {message.for_usergroup && (
          <div style={{ fontSize: '11px', color: '#6c757d', marginBottom: '4px' }}>
            to group: <LinkNode
              id={message.for_usergroup.node_id}
              display={message.for_usergroup.title}
            />
          </div>
        )}

        <div style={{ marginBottom: '6px' }}>
          <ParseLinks>{message.msgtext}</ParseLinks>
        </div>

        <div style={{ display: 'flex', gap: '8px', fontSize: '11px' }}>
          {!message.archive ? (
            <>
              <button
                onClick={() => handleArchive(message.message_id)}
                style={{
                  padding: '2px 8px',
                  fontSize: '11px',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer'
                }}
              >
                Archive
              </button>
              <button
                onClick={() => handleDelete(message.message_id)}
                style={{
                  padding: '2px 8px',
                  fontSize: '11px',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  backgroundColor: '#fff',
                  cursor: 'pointer',
                  color: '#dc3545'
                }}
              >
                Delete
              </button>
            </>
          ) : (
            <button
              onClick={() => handleUnarchive(message.message_id)}
              style={{
                padding: '2px 8px',
                fontSize: '11px',
                border: '1px solid #dee2e6',
                borderRadius: '3px',
                backgroundColor: '#fff',
                cursor: 'pointer'
              }}
            >
              Unarchive
            </button>
          )}
        </div>
      </div>
    )
  }

  return (
    <NodeletContainer
      title="Messages"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {error && (
        <div style={{
          backgroundColor: '#fee',
          border: '1px solid #fcc',
          borderRadius: '4px',
          padding: '8px',
          marginBottom: '8px',
          fontSize: '11px',
          color: '#c33'
        }}>
          {error}
        </div>
      )}

      <div style={{ marginBottom: '8px' }}>
        <button
          onClick={() => loadMessages(false)}
          disabled={loading || !showArchived}
          style={{
            padding: '4px 12px',
            fontSize: '12px',
            border: '1px solid #dee2e6',
            borderRadius: '3px',
            backgroundColor: !showArchived ? '#e9ecef' : '#fff',
            cursor: !showArchived || loading ? 'not-allowed' : 'pointer',
            marginRight: '4px'
          }}
        >
          Inbox
        </button>
        <button
          onClick={() => loadMessages(true)}
          disabled={loading || showArchived}
          style={{
            padding: '4px 12px',
            fontSize: '12px',
            border: '1px solid #dee2e6',
            borderRadius: '3px',
            backgroundColor: showArchived ? '#e9ecef' : '#fff',
            cursor: showArchived || loading ? 'not-allowed' : 'pointer'
          }}
        >
          Archived
        </button>
      </div>

      {loading && (
        <div style={{ padding: '12px', fontSize: '12px', color: '#999', fontStyle: 'italic', textAlign: 'center' }}>
          Loading messages...
        </div>
      )}

      {!loading && messages.length === 0 && (
        <div style={{ padding: '12px', fontSize: '12px', color: '#999', fontStyle: 'italic' }}>
          No messages
        </div>
      )}

      {!loading && messages.length > 0 && (
        <div>
          {messages.map(message => renderMessage(message))}
        </div>
      )}
    </NodeletContainer>
  )
}

export default Messages
