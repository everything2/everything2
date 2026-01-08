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

  const styles = {
    container: {
      fontFamily: 'Verdana, Arial, Helvetica, sans-serif',
      fontSize: '10pt',
      maxWidth: '800px',
      margin: '0 auto'
    },
    header: {
      fontSize: '14pt',
      fontWeight: 'bold',
      marginBottom: '16px',
      color: '#38495e'
    },
    section: {
      backgroundColor: '#f8f9f9',
      border: '1px solid #38495e',
      borderRadius: '4px',
      padding: '16px',
      marginBottom: '16px'
    },
    sectionTitle: {
      fontSize: '11pt',
      fontWeight: 'bold',
      marginBottom: '12px',
      color: '#38495e'
    },
    inputGroup: {
      marginBottom: '12px'
    },
    checkboxLabel: {
      display: 'inline-flex',
      alignItems: 'center',
      marginRight: '16px',
      cursor: 'pointer'
    },
    checkbox: {
      marginRight: '6px'
    },
    button: {
      padding: '6px 16px',
      backgroundColor: '#4060b0',
      color: 'white',
      border: 'none',
      borderRadius: '3px',
      fontSize: '10pt',
      cursor: 'pointer',
      fontWeight: 'bold'
    },
    buttonDisabled: {
      padding: '6px 16px',
      backgroundColor: '#ccc',
      color: '#666',
      border: 'none',
      borderRadius: '3px',
      fontSize: '10pt',
      cursor: 'not-allowed',
      fontWeight: 'bold'
    },
    buttonSecondary: {
      padding: '4px 12px',
      backgroundColor: '#507898',
      color: 'white',
      border: 'none',
      borderRadius: '3px',
      fontSize: '9pt',
      cursor: 'pointer',
      marginLeft: '8px'
    },
    buttonDanger: {
      padding: '4px 12px',
      backgroundColor: '#c33',
      color: 'white',
      border: 'none',
      borderRadius: '3px',
      fontSize: '9pt',
      cursor: 'pointer',
      marginLeft: '8px'
    },
    list: {
      listStyle: 'none',
      padding: 0,
      margin: 0
    },
    listItem: {
      padding: '12px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    },
    userInfo: {
      flex: 1
    },
    username: {
      fontWeight: 'bold',
      color: '#4060b0',
      marginRight: '12px'
    },
    blockTypes: {
      fontSize: '9pt',
      color: '#507898',
      display: 'flex',
      gap: '12px',
      marginTop: '4px'
    },
    actions: {
      display: 'flex',
      gap: '8px'
    },
    message: {
      padding: '8px 12px',
      borderRadius: '3px',
      marginBottom: '12px'
    },
    error: {
      backgroundColor: '#fee',
      color: '#c33',
      border: '1px solid #c33'
    },
    success: {
      backgroundColor: '#efe',
      color: '#383',
      border: '1px solid #383'
    },
    emptyState: {
      textAlign: 'center',
      padding: '24px',
      color: '#507898',
      fontStyle: 'italic'
    }
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>Manage Blocked Users</div>

      {error && (
        <div style={{ ...styles.message, ...styles.error }}>
          {error}
        </div>
      )}

      {success && (
        <div style={{ ...styles.message, ...styles.success }}>
          {success}
        </div>
      )}

      <div style={styles.section}>
        <div style={styles.sectionTitle}>Block a User</div>
        <div style={styles.inputGroup}>
          <UserSearchInput
            onSelect={addBlockedUser}
            placeholder="Search for a user to block..."
            buttonText={loading ? 'Adding...' : 'Block User'}
            disabled={loading}
          />
        </div>
        <div style={styles.inputGroup}>
          <label style={styles.checkboxLabel}>
            <input
              type="checkbox"
              style={styles.checkbox}
              checked={hideWriteups}
              onChange={(e) => setHideWriteups(e.target.checked)}
              disabled={loading}
            />
            <span>
              <strong>Hide writeups</strong>
              <div style={{ fontSize: '9pt', color: '#507898', marginTop: '2px' }}>
                Don't show their writeups in New Writeups
              </div>
            </span>
          </label>
          <label style={styles.checkboxLabel}>
            <input
              type="checkbox"
              style={styles.checkbox}
              checked={blockMessages}
              onChange={(e) => setBlockMessages(e.target.checked)}
              disabled={loading}
            />
            <span>
              <strong>Block messages</strong>
              <div style={{ fontSize: '9pt', color: '#507898', marginTop: '2px' }}>
                Block their private messages and chat
              </div>
            </span>
          </label>
        </div>
      </div>

      <div style={styles.section}>
        <div style={styles.sectionTitle}>
          Blocked Users ({blockedUsers.length})
        </div>
        {blockedUsers.length === 0 ? (
          <div style={styles.emptyState}>
            No blocked users
          </div>
        ) : (
          <ul style={styles.list}>
            {blockedUsers.map((user, index) => (
              <li key={user.node_id} style={{
                ...styles.listItem,
                borderBottom: index === blockedUsers.length - 1 ? 'none' : '1px solid #ddd'
              }}>
                <div style={styles.userInfo}>
                  <div>
                    <span style={styles.username}>{user.title}</span>
                  </div>
                  <div style={styles.blockTypes}>
                    <label style={styles.checkboxLabel}>
                      <input
                        type="checkbox"
                        style={styles.checkbox}
                        checked={user.hide_writeups === 1}
                        onChange={(e) => updateBlockedUser(user.node_id, {
                          hide_writeups: e.target.checked,
                          block_messages: user.block_messages
                        })}
                        disabled={loading}
                      />
                      Hide writeups
                    </label>
                    <label style={styles.checkboxLabel}>
                      <input
                        type="checkbox"
                        style={styles.checkbox}
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
                <div style={styles.actions}>
                  <button
                    style={styles.buttonDanger}
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
