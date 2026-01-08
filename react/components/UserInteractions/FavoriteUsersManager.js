import React, { useState, useCallback } from 'react'
import PropTypes from 'prop-types'
import UserSearchInput from '../UserSearchInput'
import LinkNode from '../LinkNode'
import ConfirmModal from '../ConfirmModal'

/**
 * FavoriteUsersManager - Component for managing favorite users (following)
 *
 * Favorite users allow you to follow other noders and see their
 * recent writeups in the Favorite Noders nodelet.
 */
const FavoriteUsersManager = ({ initialFavorites = [], currentUser }) => {
  const [favoriteUsers, setFavoriteUsers] = useState(initialFavorites)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [success, setSuccess] = useState(null)
  const [confirmModal, setConfirmModal] = useState({ isOpen: false, userId: null, username: '' })

  const addFavoriteUser = useCallback(async (user) => {
    const username = user.title
    if (!username || !username.trim()) {
      setError('Please enter a username')
      return
    }

    // Check if user is trying to favorite themselves
    if (currentUser && username.toLowerCase() === currentUser.title.toLowerCase()) {
      setError('You cannot favorite yourself')
      return
    }

    // Check if already favorited
    if (favoriteUsers.some(u => u.title.toLowerCase() === username.toLowerCase())) {
      setError(`${username} is already in your favorites`)
      return
    }

    setLoading(true)
    setError(null)
    setSuccess(null)

    try {
      // First, look up the user to get their node_id if we don't have it
      let userId = user.node_id
      if (!userId) {
        const lookupResponse = await fetch(
          `/api/node_search?q=${encodeURIComponent(username)}&scope=users&limit=1`
        )
        const lookupData = await lookupResponse.json()
        if (lookupData.success && lookupData.results && lookupData.results.length > 0) {
          const foundUser = lookupData.results.find(
            u => u.title.toLowerCase() === username.toLowerCase()
          )
          if (foundUser) {
            userId = foundUser.node_id
          }
        }
      }

      if (!userId) {
        setError(`User "${username}" not found`)
        setLoading(false)
        return
      }

      const response = await fetch(`/api/favorites/${userId}/action/favorite`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          // Add to local state
          setFavoriteUsers(prev => [...prev, {
            node_id: data.node_id,
            title: data.title
          }])
          setSuccess(`Now following ${data.title}`)
        } else {
          setError(data.error || 'Failed to add favorite')
        }
      } else {
        setError('Failed to add favorite')
      }
    } catch (err) {
      setError('Network error: ' + err.message)
    } finally {
      setLoading(false)
    }
  }, [currentUser, favoriteUsers])

  const openRemoveModal = useCallback((userId, username) => {
    setConfirmModal({ isOpen: true, userId, username })
  }, [])

  const closeRemoveModal = useCallback(() => {
    setConfirmModal({ isOpen: false, userId: null, username: '' })
  }, [])

  const confirmRemoveFavoriteUser = useCallback(async () => {
    const { userId, username } = confirmModal
    if (!userId) return

    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/favorites/${userId}/action/unfavorite`, {
        method: 'POST',
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          setFavoriteUsers(prev => prev.filter(user => user.node_id !== userId))
          setSuccess(`Stopped following ${username}`)
        } else {
          setError(data.error || 'Failed to remove favorite')
        }
      } else {
        setError('Failed to remove favorite')
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
      color: '#4060b0'
    },
    actions: {
      display: 'flex',
      gap: '8px'
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
    },
    description: {
      fontSize: '9pt',
      color: '#507898',
      marginBottom: '12px',
      lineHeight: '1.4'
    }
  }

  return (
    <div style={styles.container}>
      <div style={styles.header}>Favorite Users</div>

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
        <div style={styles.sectionTitle}>Follow a User</div>
        <div style={styles.description}>
          Follow users to see their recent writeups in the Favorite Noders nodelet.
          You can also favorite users by clicking the star icon on their homenode.
        </div>
        <div style={styles.inputGroup}>
          <UserSearchInput
            onSelect={addFavoriteUser}
            placeholder="Search for a user to follow..."
            buttonText={loading ? 'Adding...' : 'Follow'}
            disabled={loading}
          />
        </div>
      </div>

      <div style={styles.section}>
        <div style={styles.sectionTitle}>
          Following ({favoriteUsers.length})
        </div>
        {favoriteUsers.length === 0 ? (
          <div style={styles.emptyState}>
            You're not following anyone yet
          </div>
        ) : (
          <ul style={styles.list}>
            {favoriteUsers.map((user, index) => (
              <li key={user.node_id} style={{
                ...styles.listItem,
                borderBottom: index === favoriteUsers.length - 1 ? 'none' : '1px solid #ddd'
              }}>
                <div style={styles.userInfo}>
                  <LinkNode type="user" title={user.title} style={styles.username} />
                </div>
                <div style={styles.actions}>
                  <button
                    style={styles.buttonDanger}
                    onClick={() => openRemoveModal(user.node_id, user.title)}
                    disabled={loading}
                  >
                    Unfollow
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
        onConfirm={confirmRemoveFavoriteUser}
        title="Unfollow User"
        message={`Are you sure you want to stop following ${confirmModal.username}?`}
        confirmText="Unfollow"
        cancelText="Cancel"
        confirmColor="#c33"
      />
    </div>
  )
}

FavoriteUsersManager.propTypes = {
  initialFavorites: PropTypes.arrayOf(PropTypes.shape({
    node_id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]).isRequired,
    title: PropTypes.string.isRequired
  })),
  currentUser: PropTypes.shape({
    node_id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    title: PropTypes.string
  })
}

export default FavoriteUsersManager
