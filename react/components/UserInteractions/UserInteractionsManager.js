import React, { useState, useCallback } from 'react'
import PropTypes from 'prop-types'
import UserSearchInput from '../UserSearchInput'
import ConfirmModal from '../ConfirmModal'

/**
 * UserInteractionsManager - Unified component for managing blocked/unfavorite users
 *
 * Manages two types of blocks:
 * - Hide writeups: Prevents user's writeups from appearing in New Writeups
 * - Block messages: Prevents private messages and chat from the user
 */
const UserInteractionsManager = ({ initialBlocked = [], currentUser }) => {
  const [blockedUsers, setBlockedUsers] = useState(initialBlocked)
  const [hideWriteups, setHideWriteups] = useState(true)
  const [blockMessages, setBlockMessages] = useState(true)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [confirmModal, setConfirmModal] = useState({ isOpen: false, userId: null, username: '' })

  const fetchBlockedUsers = useCallback(async () => {
    try {
      const response = await fetch('/api/userinteractions/', {
        credentials: 'same-origin'
      })
      if (response.ok) {
        const data = await response.json()
        setBlockedUsers(data.blocked_users || [])
      }
    } catch (err) {
      console.error('Error fetching blocked users:', err)
    }
  }, [])

  const addBlockedUser = useCallback(async (user) => {
    const username = user.title
    if (!username || !username.trim()) {
      setError('Please enter a username')
      return
    }

    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      const response = await fetch('/api/userinteractions/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          username: username.trim(),
          hide_writeups: hideWriteups,
          block_messages: blockMessages
        })
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          setBlockedUsers(prev => [...prev, data])
          setSuccess(`Successfully blocked ${data.title}`)
        } else {
          setError(data.error || 'Failed to block user')
        }
      } else {
        setError('Failed to block user')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }, [hideWriteups, blockMessages])

  const updateBlockedUser = useCallback(async (userId, updates) => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/userinteractions/${userId}/action/update`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify(updates)
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          setBlockedUsers(prev => prev.map(user =>
            user.node_id === userId ? data : user
          ))
        } else {
          setError(data.error || 'Failed to update block settings')
        }
      } else {
        setError('Failed to update block settings')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  const openRemoveModal = useCallback((userId, username) => {
    setConfirmModal({ isOpen: true, userId, username })
  }, [])

  const closeRemoveModal = useCallback(() => {
    setConfirmModal({ isOpen: false, userId: null, username: '' })
  }, [])

  const confirmRemoveBlockedUser = useCallback(async () => {
    const { userId, username } = confirmModal
    if (!userId) return

    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/userinteractions/${userId}/action/delete`, {
        method: 'DELETE',
        credentials: 'same-origin'
      })

      if (response.ok) {
        setBlockedUsers(prev => prev.filter(user => user.node_id !== userId))
        setSuccess(`Removed blocks for ${username}`)
      } else {
        setError('Failed to remove blocks')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }, [confirmModal])

  return (
    <div className="user-manager">
      <div className="user-manager__header">Manage Blocked Users</div>

      {error && (
        <div className="user-manager__message user-manager__message--error">
          {error}
        </div>
      )}

      {success && (
        <div className="user-manager__message user-manager__message--success">
          {success}
        </div>
      )}

      <div className="user-manager__section">
        <div className="user-manager__section-title">Block a User</div>
        <div className="user-manager__input-group">
          <UserSearchInput
            onSelect={addBlockedUser}
            placeholder="Search for a user to block..."
            buttonText={loading ? 'Adding...' : 'Block User'}
            disabled={loading}
          />
        </div>
        <div className="user-manager__input-group">
          <label className="user-manager__checkbox-label">
            <input
              type="checkbox"
              className="user-manager__checkbox"
              checked={hideWriteups}
              onChange={(e) => setHideWriteups(e.target.checked)}
              disabled={loading}
            />
            <span>
              <strong>Hide writeups</strong>
              <div className="user-manager__checkbox-hint">
                Don't show their writeups in New Writeups
              </div>
            </span>
          </label>
          <label className="user-manager__checkbox-label">
            <input
              type="checkbox"
              className="user-manager__checkbox"
              checked={blockMessages}
              onChange={(e) => setBlockMessages(e.target.checked)}
              disabled={loading}
            />
            <span>
              <strong>Block messages</strong>
              <div className="user-manager__checkbox-hint">
                Block their private messages and chat
              </div>
            </span>
          </label>
        </div>
      </div>

      <div className="user-manager__section">
        <div className="user-manager__section-title">
          Blocked Users ({blockedUsers.length})
        </div>
        {blockedUsers.length === 0 ? (
          <div className="user-manager__empty-state">
            No blocked users
          </div>
        ) : (
          <ul className="user-manager__list">
            {blockedUsers.map((user) => (
              <li key={user.node_id} className="user-manager__list-item">
                <div className="user-manager__user-info">
                  <div>
                    <span className="user-manager__username">{user.title}</span>
                  </div>
                  <div className="user-manager__block-types">
                    <label className="user-manager__checkbox-label">
                      <input
                        type="checkbox"
                        className="user-manager__checkbox"
                        checked={user.hide_writeups === 1}
                        onChange={(e) => updateBlockedUser(user.node_id, {
                          hide_writeups: e.target.checked,
                          block_messages: user.block_messages
                        })}
                        disabled={loading}
                      />
                      Hide writeups
                    </label>
                    <label className="user-manager__checkbox-label">
                      <input
                        type="checkbox"
                        className="user-manager__checkbox"
                        checked={user.block_messages === 1}
                        onChange={(e) => updateBlockedUser(user.node_id, {
                          hide_writeups: user.hide_writeups,
                          block_messages: e.target.checked
                        })}
                        disabled={loading}
                      />
                      Block messages
                    </label>
                  </div>
                </div>
                <div className="user-manager__actions">
                  <button
                    className="user-manager__btn--danger"
                    onClick={() => openRemoveModal(user.node_id, user.title)}
                    disabled={loading}
                  >
                    Remove
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <ConfirmModal
        isOpen={confirmModal.isOpen}
        onClose={closeRemoveModal}
        onConfirm={confirmRemoveBlockedUser}
        title="Remove Block"
        message={`Are you sure you want to remove all blocks for ${confirmModal.username}?`}
        confirmText="Remove"
        cancelText="Cancel"
        confirmColor="#c33"
      />
    </div>
  )
}

UserInteractionsManager.propTypes = {
  initialBlocked: PropTypes.arrayOf(PropTypes.shape({
    node_id: PropTypes.number.isRequired,
    title: PropTypes.string.isRequired,
    type: PropTypes.string.isRequired,
    hide_writeups: PropTypes.number.isRequired,
    block_messages: PropTypes.number.isRequired
  })),
  currentUser: PropTypes.shape({
    node_id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    title: PropTypes.string
  })
}

export default UserInteractionsManager
