import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import { useOtherUsersPolling } from '../../hooks/useOtherUsersPolling'

const OtherUsers = (props) => {
  const [selectedRoom, setSelectedRoom] = React.useState(null)
  const [isCloaked, setIsCloaked] = React.useState(false)
  const [isChangingRoom, setIsChangingRoom] = React.useState(false)
  const [isTogglingCloak, setIsTogglingCloak] = React.useState(false)
  const [showCreateDialog, setShowCreateDialog] = React.useState(false)
  const [newRoomTitle, setNewRoomTitle] = React.useState('')
  const [newRoomDescription, setNewRoomDescription] = React.useState('')
  const [isCreatingRoom, setIsCreatingRoom] = React.useState(false)
  const [error, setError] = React.useState(null)

  // Use polling hook for automatic updates every 2 minutes
  // Pass initial data from props to skip initial API call
  const { otherUsersData: polledData, loading: pollingLoading, error: pollingError, refresh } = useOtherUsersPolling(120000, props.otherUsersData)

  // Use polled data (which now includes initial data from props)
  const otherUsersData = polledData

  // Extract data with defaults - MUST be before any conditional returns to maintain hook order
  const {
    userCount,
    currentRoom,
    currentRoomId,
    rooms,
    availableRooms,
    canCloak,
    isCloaked: initialCloaked,
    suspension,
    canCreateRoom,
    createRoomSuspended
  } = otherUsersData || {}

  // Initialize states from props and sync with updates - MUST be before any conditional returns
  React.useEffect(() => {
    if (currentRoomId !== undefined) {
      setSelectedRoom(currentRoomId)
    }
    if (initialCloaked !== undefined) {
      setIsCloaked(initialCloaked)
    }
  }, [currentRoomId, initialCloaked])

  // NOW we can do conditional returns after all hooks are called
  if (!otherUsersData) {
    return (
      <NodeletContainer
        id={props.id}
        title="Other Users"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', fontSize: '12px', fontStyle: 'italic' }}>
          {pollingLoading ? 'Loading...' : pollingError ? `Error: ${pollingError}` : 'No chat data available'}
        </p>
      </NodeletContainer>
    )
  }

  const handleChangeRoom = async () => {
    if (selectedRoom === null || selectedRoom === currentRoomId) return

    setIsChangingRoom(true)
    setError(null)

    try {
      const response = await fetch('/api/chatroom/change_room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          room_id: selectedRoom
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || 'Failed to change room')
      }

      // Update state with new room data from API (pass full response to get room_name and room_topic)
      if (data.otherUsersData && props.onOtherUsersDataUpdate) {
        props.onOtherUsersDataUpdate(data)
      } else {
        // Fallback to reload if callback not provided
        window.location.reload()
      }

      // Refresh polling data immediately to get updated room info
      refresh()
    } catch (error) {
      setError(error.message)
    } finally {
      setIsChangingRoom(false)
    }
  }

  const handleToggleCloak = async (e) => {
    const checked = e.target.checked

    setIsTogglingCloak(true)
    setError(null)

    try {
      const response = await fetch('/api/chatroom/set_cloaked', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          cloaked: checked ? 1 : 0
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || 'Failed to toggle cloak')
      }

      setIsCloaked(checked)

      // Update otherUsersData with new cloak status
      if (data.otherUsersData && props.onOtherUsersDataUpdate) {
        props.onOtherUsersDataUpdate(data.otherUsersData)
      }
    } catch (error) {
      setError(error.message)
      setIsCloaked(!checked) // Revert on error
    } finally {
      setIsTogglingCloak(false)
    }
  }

  const handleCreateRoom = async (e) => {
    e.preventDefault()

    if (!newRoomTitle.trim()) {
      setError('Room title is required')
      return
    }

    setIsCreatingRoom(true)
    setError(null)

    try {
      const response = await fetch('/api/chatroom/create_room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          room_title: newRoomTitle,
          room_doctext: newRoomDescription
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || 'Failed to create room')
      }

      // Room created and user moved to it - close dialog and update state
      setShowCreateDialog(false)
      setNewRoomTitle('')
      setNewRoomDescription('')

      // Update state with new room data from API (pass full response to get room_name and room_topic)
      if (data.otherUsersData && props.onOtherUsersDataUpdate) {
        props.onOtherUsersDataUpdate(data)
      } else {
        // Fallback to reload if callback not provided
        window.location.reload()
      }

      // Refresh polling data immediately to get updated room info
      refresh()
    } catch (error) {
      setError(error.message)
    } finally {
      setIsCreatingRoom(false)
    }
  }

  // Render user flags
  const renderFlags = (flags) => {
    if (!flags || flags.length === 0) return null

    return (
      <span>
        {' '}
        &nbsp;[
        {flags.map((flag, idx) => (
          <React.Fragment key={idx}>
            {flag.type === 'newuser' && (
              flag.veryNew ? (
                <strong className="newdays" title="very new user">{flag.days}</strong>
              ) : (
                <span className="newdays" title="new user">{flag.days}</span>
              )
            )}
            {flag.type === 'god' && (
              <LinkNode title="E2 staff" type="superdoc" display="@" style={{ textDecoration: 'none' }} titleAttr="e2gods" />
            )}
            {flag.type === 'editor' && (
              <LinkNode title="E2 staff" type="superdoc" display="$" style={{ textDecoration: 'none' }} titleAttr="Content Editors" />
            )}
            {flag.type === 'chanop' && (
              <LinkNode title="E2 staff" type="superdoc" display="+" style={{ textDecoration: 'none' }} titleAttr="chanops" />
            )}
            {flag.type === 'borged' && (
              <LinkNode title="E2 FAQ: Chatterbox" type="superdoc" display="Ø" style={{ textDecoration: 'none' }} titleAttr="borged!" />
            )}
            {flag.type === 'invisible' && (
              <font color="#ff0000">i</font>
            )}
            {flag.type === 'room' && (
              <LinkNode id={flag.roomId} display="~" />
            )}
          </React.Fragment>
        ))}
        ]
      </span>
    )
  }

  // Render user action or recent noding
  const renderAction = (action) => {
    if (!action) return null

    if (action.type === 'action') {
      const text = action.verb && action.noun ? `${action.verb} ${action.noun}` : ''
      if (!text) return null
      return <small> is {text}</small>
    }

    if (action.type === 'recent') {
      return (
        <small>
          {' '}has recently noded{' '}
          <LinkNode id={action.nodeId} display={action.parentTitle} />
        </small>
      )
    }

    return null
  }

  // Render individual user
  const renderUser = (user) => {
    const userLink = (
      <LinkNode
        id={user.userId}
        display={user.displayName}
        lastnode_id={0}
      />
    )

    return (
      <>
        {user.isCurrentUser ? <strong>{userLink}</strong> : userLink}
        {renderFlags(user.flags)}
        {renderAction(user.action)}
      </>
    )
  }

  // Render Room Options section with clean, minimalist design
  const renderRoomOptions = () => {
    return (
      <div style={{
        background: '#f8f9fa',
        border: '1px solid #dee2e6',
        borderRadius: '4px',
        padding: '12px',
        marginBottom: '12px'
      }}>
        <h4 style={{
          margin: '0 0 10px 0',
          fontSize: '13px',
          fontWeight: '600',
          color: '#495057',
          letterSpacing: '0'
        }}>
          Room Options
        </h4>

        {error && (
          <div style={{
            backgroundColor: '#fee',
            border: '1px solid #fcc',
            borderRadius: '4px',
            padding: '8px',
            marginBottom: '12px',
            fontSize: '11px',
            color: '#c33'
          }}>
            {error}
          </div>
        )}

        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            {!!canCloak && (
              <label style={{
                display: 'flex',
                alignItems: 'center',
                fontSize: '11px',
                color: '#6c757d',
                cursor: 'pointer',
                padding: '4px 8px',
                backgroundColor: '#fff',
                border: '1px solid #dee2e6',
                borderRadius: '3px',
                transition: 'border-color 0.2s',
                flex: '0 0 auto'
              }}>
                <input
                  type="checkbox"
                  checked={isCloaked}
                  onChange={handleToggleCloak}
                  disabled={isTogglingCloak}
                  style={{ marginRight: '6px' }}
                />
                Cloaked
              </label>
            )}

            {!!canCreateRoom && !createRoomSuspended && (
              <button
                onClick={() => setShowCreateDialog(true)}
                style={{
                  backgroundColor: '#fff',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  padding: '5px 12px',
                  fontSize: '12px',
                  color: '#495057',
                  cursor: 'pointer',
                  fontWeight: '500',
                  transition: 'all 0.2s',
                  flex: '1 1 auto'
                }}
                onMouseOver={(e) => { e.currentTarget.style.backgroundColor = '#f8f9fa'; e.currentTarget.style.borderColor = '#adb5bd' }}
                onMouseOut={(e) => { e.currentTarget.style.backgroundColor = '#fff'; e.currentTarget.style.borderColor = '#dee2e6' }}
              >
                New Room
              </button>
            )}
          </div>

          {suspension ? (
            <div style={{
              backgroundColor: '#fff',
              border: '1px solid #dee2e6',
              borderRadius: '3px',
              padding: '8px',
              fontSize: '11px',
              color: '#6c757d',
              fontStyle: 'italic'
            }}>
              {suspension.type === 'temporary'
                ? `Locked here for ${suspension.seconds_remaining} seconds`
                : 'Locked here indefinitely'}
            </div>
          ) : (
            <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
              <select
                value={selectedRoom !== null ? selectedRoom : currentRoomId}
                onChange={(e) => setSelectedRoom(parseInt(e.target.value))}
                disabled={isChangingRoom}
                style={{
                  flex: 1,
                  padding: '6px 8px',
                  fontSize: '12px',
                  borderRadius: '3px',
                  border: '1px solid #dee2e6',
                  backgroundColor: '#fff',
                  color: '#495057',
                  cursor: 'pointer'
                }}
              >
                {availableRooms.map((room) => (
                  <option key={room.room_id} value={room.room_id}>
                    {room.title}
                  </option>
                ))}
              </select>
              <button
                onClick={handleChangeRoom}
                disabled={isChangingRoom || selectedRoom === currentRoomId}
                style={{
                  backgroundColor: selectedRoom === currentRoomId ? '#e9ecef' : '#fff',
                  border: '1px solid #dee2e6',
                  borderRadius: '3px',
                  padding: '6px 14px',
                  fontSize: '12px',
                  color: selectedRoom === currentRoomId ? '#adb5bd' : '#495057',
                  cursor: selectedRoom === currentRoomId ? 'not-allowed' : 'pointer',
                  fontWeight: '500',
                  transition: 'all 0.2s',
                  minWidth: '45px'
                }}
              >
                {isChangingRoom ? '...' : 'Go'}
              </button>
            </div>
          )}
        </div>
      </div>
    )
  }

  // Render Create Room Dialog
  const renderCreateDialog = () => {
    if (!showCreateDialog) return null

    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.6)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 10000,
        backdropFilter: 'blur(4px)'
      }}>
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '12px',
          padding: '24px',
          maxWidth: '500px',
          width: '90%',
          boxShadow: '0 10px 40px rgba(0,0,0,0.3)'
        }}>
          <h3 style={{
            margin: '0 0 20px 0',
            fontSize: '18px',
            fontWeight: 'bold',
            color: '#333',
            borderBottom: '2px solid #667eea',
            paddingBottom: '12px'
          }}>
            Create New Room
          </h3>

          {error && (
            <div style={{
              backgroundColor: '#fee',
              border: '1px solid #fcc',
              borderRadius: '6px',
              padding: '10px',
              marginBottom: '16px',
              fontSize: '12px',
              color: '#c33'
            }}>
              {error}
            </div>
          )}

          <form onSubmit={handleCreateRoom}>
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                marginBottom: '6px',
                fontSize: '13px',
                fontWeight: '600',
                color: '#555'
              }}>
                Room Name
              </label>
              <input
                type="text"
                value={newRoomTitle}
                onChange={(e) => setNewRoomTitle(e.target.value)}
                maxLength={80}
                placeholder="Enter a unique room name..."
                style={{
                  width: '100%',
                  fontSize: '13px',
                  padding: '10px',
                  border: '2px solid #ddd',
                  borderRadius: '6px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#ddd'}
                autoFocus
              />
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '6px',
                fontSize: '13px',
                fontWeight: '600',
                color: '#555'
              }}>
                Description
              </label>
              <textarea
                value={newRoomDescription}
                onChange={(e) => setNewRoomDescription(e.target.value)}
                rows={4}
                placeholder="Describe your room..."
                style={{
                  width: '100%',
                  fontSize: '13px',
                  padding: '10px',
                  border: '2px solid #ddd',
                  borderRadius: '6px',
                  boxSizing: 'border-box',
                  resize: 'vertical',
                  transition: 'border-color 0.2s',
                  fontFamily: 'inherit'
                }}
                onFocus={(e) => e.target.style.borderColor = '#667eea'}
                onBlur={(e) => e.target.style.borderColor = '#ddd'}
              />
            </div>

            <div style={{
              backgroundColor: '#f8f9fa',
              border: '1px solid #dee2e6',
              borderRadius: '6px',
              padding: '12px',
              marginBottom: '20px',
              fontSize: '11px',
              color: '#6c757d',
              lineHeight: '1.5'
            }}>
              <strong>Note:</strong> Old rooms that are not used will be automatically cleaned up over time.
              Room titles and descriptions are subject to community standards.
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button
                type="button"
                onClick={() => {
                  setShowCreateDialog(false)
                  setNewRoomTitle('')
                  setNewRoomDescription('')
                  setError(null)
                }}
                disabled={isCreatingRoom}
                style={{
                  fontSize: '13px',
                  padding: '10px 20px',
                  border: '2px solid #ddd',
                  borderRadius: '6px',
                  backgroundColor: '#fff',
                  color: '#666',
                  cursor: 'pointer',
                  fontWeight: '600',
                  transition: 'all 0.2s'
                }}
                onMouseOver={(e) => { e.currentTarget.style.backgroundColor = '#f5f5f5'; e.currentTarget.style.borderColor = '#999' }}
                onMouseOut={(e) => { e.currentTarget.style.backgroundColor = '#fff'; e.currentTarget.style.borderColor = '#ddd' }}
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isCreatingRoom || !newRoomTitle.trim()}
                style={{
                  fontSize: '13px',
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '6px',
                  background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                  color: '#fff',
                  cursor: isCreatingRoom || !newRoomTitle.trim() ? 'not-allowed' : 'pointer',
                  fontWeight: '600',
                  opacity: isCreatingRoom || !newRoomTitle.trim() ? 0.6 : 1,
                  transition: 'all 0.2s',
                  boxShadow: '0 2px 8px rgba(102, 126, 234, 0.4)'
                }}
                onMouseOver={(e) => {
                  if (!isCreatingRoom && newRoomTitle.trim()) {
                    e.currentTarget.style.transform = 'translateY(-1px)'
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(102, 126, 234, 0.5)'
                  }
                }}
                onMouseOut={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)'
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(102, 126, 234, 0.4)'
                }}
              >
                {isCreatingRoom ? 'Creating...' : 'Create Room'}
              </button>
            </div>
          </form>
        </div>
      </div>
    )
  }

  if (userCount === 0) {
    return (
      <NodeletContainer
        id={props.id}
      title="Other Users"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        {renderRoomOptions()}
        <div style={{ padding: '12px', fontSize: '12px', color: '#999', fontStyle: 'italic' }}>
          There are no noders in this room.
        </div>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Other Users"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {renderRoomOptions()}

      <div style={{
        backgroundColor: '#f8f9fa',
        borderRadius: '4px',
        padding: '6px 8px',
        marginBottom: '4px'
      }}>
        <h4 style={{
          fontSize: '13px',
          fontWeight: 'bold',
          margin: '0',
          color: '#495057'
        }}>
          Your fellow users ({userCount})
        </h4>
      </div>

      {rooms.map((room, roomIndex) => (
        <React.Fragment key={roomIndex}>
          {room.title && (
            <div style={{
              fontSize: '12px',
              fontWeight: '600',
              marginTop: roomIndex > 0 ? '12px' : '0',
              marginBottom: '6px',
              color: '#667eea',
              borderBottom: '1px solid #e9ecef',
              paddingBottom: '4px'
            }}>
              {room.title}:
            </div>
          )}
          <ul style={{
            listStyle: 'none',
            paddingLeft: '0',
            margin: '0',
            fontSize: '12px'
          }}>
            {room.users.map((user, userIndex) => (
              <li key={userIndex} style={{
                marginBottom: '2px',
                padding: '3px 6px',
                backgroundColor: user.isCurrentUser ? '#f0f4ff' : 'transparent',
                borderRadius: '3px',
                transition: 'background-color 0.2s'
              }}>
                {renderUser(user)}
              </li>
            ))}
          </ul>
        </React.Fragment>
      ))}
      {renderCreateDialog()}
    </NodeletContainer>
  )
}

export default OtherUsers
