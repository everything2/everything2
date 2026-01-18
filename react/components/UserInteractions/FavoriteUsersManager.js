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

  return (
    <div className="user-manager">
      <div className="user-manager__header">Favorite Users</div>

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
        <div className="user-manager__section-title">Follow a User</div>
        <div className="user-manager__description">
          Follow users to see their recent writeups in the Favorite Noders nodelet.
          You can also favorite users by clicking the star icon on their homenode.
        </div>
        <div className="user-manager__input-group">
          <UserSearchInput
            onSelect={addFavoriteUser}
            placeholder="Search for a user to follow..."
            buttonText={loading ? 'Adding...' : 'Follow'}
            disabled={loading}
          />
        </div>
      </div>

      <div className="user-manager__section">
        <div className="user-manager__section-title">
          Following ({favoriteUsers.length})
        </div>
        {favoriteUsers.length === 0 ? (
          <div className="user-manager__empty-state">
            You're not following anyone yet
          </div>
        ) : (
          <ul className="user-manager__list">
            {favoriteUsers.map((user) => (
              <li key={user.node_id} className="user-manager__list-item">
                <div className="user-manager__user-info">
                  <LinkNode type="user" title={user.title} className="user-manager__username-link" />
                </div>
                <div className="user-manager__actions">
                  <button
                    className="user-manager__btn--danger"
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
