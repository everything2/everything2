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
  const { otherUsersData: polledData, loading: pollingLoading, error: pollingError, refresh, setOtherUsersData } = useOtherUsersPolling(120000, props.otherUsersData)

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
        <p className="otherusers-loading">
          {pollingLoading ? 'Loading...' : pollingError ? `Error: ${pollingError}` : 'No chat data available'}
        </p>
      </NodeletContainer>
    )
  }

  // Fires on dropdown change (no more [Go] button). targetRoomId is the
  // newly selected id; selectedRoom is the optimistic local state so the
  // dropdown doesn't visually snap back during the API round-trip.
  const handleChangeRoom = async (targetRoomId) => {
    if (targetRoomId === null || targetRoomId === currentRoomId) return

    setSelectedRoom(targetRoomId)
    setIsChangingRoom(true)
    setError(null)

    try {
      const response = await fetch('/api/chatroom/change_room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          room_id: targetRoomId
        }),
        credentials: 'include'
      })

      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error || 'Failed to change room')
      }

      // Sync the polled state directly from the response (no extra GET needed —
      // the change_room endpoint already returns updated otherUsersData).
      // Also pass the full response up so the parent can update room_name and
      // room_topic for the page-level title display.
      if (data.otherUsersData) {
        setOtherUsersData(data.otherUsersData)
        if (props.onOtherUsersDataUpdate) {
          props.onOtherUsersDataUpdate(data)
        }
      } else if (!props.onOtherUsersDataUpdate) {
        // Fallback to reload if neither path is available
        window.location.reload()
      }
    } catch (error) {
      setError(error.message)
      setSelectedRoom(currentRoomId) // Revert optimistic selection
    } finally {
      setIsChangingRoom(false)
    }
  }

  const handleToggleCloak = async (e) => {
    const checked = e.target.checked

    // Optimistic update — flip the checkbox immediately so the click
    // feels responsive. Because <input checked={isCloaked}> is controlled,
    // not flipping until after the await caused React to render the box
    // back to its old state for the entire API round-trip (~100-300ms),
    // making the click look like it did nothing. Roll back in catch.
    setIsCloaked(checked)
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

      // Sync the polled state directly from the response so the user list
      // re-renders with (or without) the invisible flag immediately. Without
      // this the cloak icon wouldn't appear until the next 2-minute poll
      // because the polling hook never re-read props.otherUsersData.
      if (data.otherUsersData) {
        setOtherUsersData(data.otherUsersData)
        if (props.onOtherUsersDataUpdate) {
          props.onOtherUsersDataUpdate(data.otherUsersData)
        }
      }
    } catch (error) {
      setError(error.message)
      setIsCloaked(!checked) // Revert optimistic flip
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
              <span className="otherusers-invisible">i</span>
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
      <div className="otherusers-room-options">
        <h4 className="otherusers-room-title">
          Room Options
        </h4>

        {error && (
          <div className="otherusers-error">
            {error}
          </div>
        )}

        <div className="otherusers-controls">
          <div className="otherusers-controls-row">
            {!!canCloak && (
              <label htmlFor="otherusers-cloaked" className="otherusers-cloak-label">
                <input
                  type="checkbox"
                  id="otherusers-cloaked"
                  name="otherusers-cloaked"
                  checked={isCloaked}
                  onChange={handleToggleCloak}
                  disabled={isTogglingCloak}
                />
                Cloaked
              </label>
            )}

            {!!canCreateRoom && !createRoomSuspended && (
              <button
                onClick={() => setShowCreateDialog(true)}
                className="otherusers-btn"
              >
                New Room
              </button>
            )}
          </div>

          {suspension ? (
            <div className="otherusers-suspension">
              {suspension.type === 'temporary'
                ? `Locked here for ${suspension.seconds_remaining} seconds`
                : 'Locked here indefinitely'}
            </div>
          ) : (
            <select
              id="otherusers-room-select"
              name="otherusers-room-select"
              value={selectedRoom !== null ? selectedRoom : currentRoomId}
              onChange={(e) => handleChangeRoom(parseInt(e.target.value))}
              disabled={isChangingRoom}
              className="otherusers-room-select"
            >
              {availableRooms.map((room) => (
                <option key={room.room_id} value={room.room_id}>
                  {room.title}
                </option>
              ))}
            </select>
          )}
        </div>
      </div>
    )
  }

  // Render Create Room Dialog
  const renderCreateDialog = () => {
    if (!showCreateDialog) return null

    return (
      <div className="otherusers-dialog-overlay">
        <div className="otherusers-dialog">
          <h3 className="otherusers-dialog-title">
            Create New Room
          </h3>

          {error && (
            <div className="otherusers-error">
              {error}
            </div>
          )}

          <form onSubmit={handleCreateRoom}>
            <div className="otherusers-dialog-field">
              <label htmlFor="otherusers-new-room-title" className="otherusers-dialog-label">
                Room Name
              </label>
              <input
                type="text"
                id="otherusers-new-room-title"
                name="otherusers-new-room-title"
                value={newRoomTitle}
                onChange={(e) => setNewRoomTitle(e.target.value)}
                maxLength={80}
                placeholder="Enter a unique room name..."
                className="otherusers-dialog-input"
                autoFocus
              />
            </div>

            <div className="otherusers-dialog-field">
              <label htmlFor="otherusers-new-room-desc" className="otherusers-dialog-label">
                Description
              </label>
              <textarea
                id="otherusers-new-room-desc"
                name="otherusers-new-room-desc"
                value={newRoomDescription}
                onChange={(e) => setNewRoomDescription(e.target.value)}
                rows={4}
                placeholder="Describe your room..."
                className="otherusers-dialog-textarea"
              />
            </div>

            <div className="otherusers-dialog-note">
              <strong>Note:</strong> Old rooms that are not used will be automatically cleaned up over time.
              Room titles and descriptions are subject to community standards.
            </div>

            <div className="otherusers-dialog-actions">
              <button
                type="button"
                onClick={() => {
                  setShowCreateDialog(false)
                  setNewRoomTitle('')
                  setNewRoomDescription('')
                  setError(null)
                }}
                disabled={isCreatingRoom}
                className="otherusers-dialog-cancel"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isCreatingRoom || !newRoomTitle.trim()}
                className="otherusers-dialog-submit"
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
        <div className="otherusers-empty">
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

      <div className="otherusers-section-header">
        <h4 className="otherusers-section-title">
          Your fellow users ({userCount})
        </h4>
      </div>

      {rooms.map((room, roomIndex) => (
        <React.Fragment key={roomIndex}>
          {/* Suppress the per-room header when there's only one room with
              users — it's redundant noise above the single user list.
              Backend now always populates room.title for API honesty (#3990),
              so the "should we render a header" decision lives here. */}
          {room.title && rooms.length > 1 && (
            <div className={`otherusers-room-label${roomIndex > 0 ? ' otherusers-room-label--offset' : ''}`}>
              {room.title}:
            </div>
          )}
          <ul className="otherusers-list">
            {room.users.map((user, userIndex) => (
              <li
                key={userIndex}
                className={`otherusers-list-item${user.isCurrentUser ? ' otherusers-list-item--current' : ''}`}
              >
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
