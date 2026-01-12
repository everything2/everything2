import React, { useState, useEffect, useCallback, useRef } from 'react'
import { FaBell, FaTimes } from 'react-icons/fa'
import ParseLinks from '../ParseLinks'

/**
 * MobileNotificationsModal - Mobile drawer for notifications
 *
 * Displays user notifications in a slide-up drawer with:
 * - List of notifications with dismiss buttons
 * - Link to notification settings
 * - Polling for updates while open
 */
const MobileNotificationsModal = ({
  isOpen,
  onClose,
  initialNotifications = null,
  onNotificationsUpdate = null
}) => {
  const [notifications, setNotifications] = useState(initialNotifications?.notifications || [])
  const [showSettings, setShowSettings] = useState(initialNotifications?.showSettings || false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const pollInterval = useRef(null)

  // Stop polling helper
  const stopPolling = useCallback(() => {
    if (pollInterval.current) {
      clearInterval(pollInterval.current)
      pollInterval.current = null
    }
  }, [])

  // Load notifications from API
  const loadNotifications = useCallback(async () => {
    if (loading) return

    setLoading(true)
    try {
      const response = await fetch('/api/notifications/', {
        credentials: 'include',
        headers: { 'X-Ajax-Idle': '1' }
      })

      if (!response.ok) {
        throw new Error(`Failed to load notifications (${response.status})`)
      }

      const data = await response.json()
      const notificationList = data.notifications || []
      setNotifications(notificationList)
      setShowSettings(data.showSettings || false)
      setError(null)

      // Notify parent of updated count
      if (onNotificationsUpdate) {
        onNotificationsUpdate(notificationList.length)
      }
    } catch (err) {
      console.error('Failed to load notifications:', err)
      setError(err.message)
      stopPolling()
    } finally {
      setLoading(false)
    }
  }, [loading, onNotificationsUpdate, stopPolling])

  // Dismiss a notification
  const handleDismiss = async (notifiedId) => {
    try {
      const response = await fetch('/api/notifications/dismiss', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ notified_id: notifiedId }),
        credentials: 'same-origin'
      })

      if (response.ok) {
        const data = await response.json()
        if (data.notifications) {
          setNotifications(data.notifications)
          // Notify parent of updated count
          if (onNotificationsUpdate) {
            onNotificationsUpdate(data.notifications.length)
          }
        }
      } else {
        console.error('Failed to dismiss notification')
      }
    } catch (err) {
      console.error('Error dismissing notification:', err)
    }
  }

  // Load notifications when modal opens
  useEffect(() => {
    if (isOpen) {
      setError(null)
      loadNotifications()
    } else {
      stopPolling()
    }

    return () => stopPolling()
  }, [isOpen])

  // Set up polling when modal is open (every 2 minutes)
  useEffect(() => {
    if (isOpen && !error) {
      pollInterval.current = setInterval(() => {
        loadNotifications()
      }, 120000)
    }

    return () => stopPolling()
  }, [isOpen, error, stopPolling])

  // Lock body scroll when modal is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  if (!isOpen) return null

  const hasNotifications = notifications.length > 0

  return (
    <div className="mobile-modal-overlay" onClick={onClose}>
      <div className="mobile-modal-drawer" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="mobile-modal-header">
          <div className="mobile-notifications-header-title">
            <FaBell className="mobile-notifications-header-icon" />
            <span>Notifications</span>
            {hasNotifications && (
              <span className="mobile-modal-badge">{notifications.length}</span>
            )}
          </div>
          <button type="button" onClick={onClose} className="mobile-modal-close-btn">
            <FaTimes />
          </button>
        </div>

        {/* Content area */}
        <div className="mobile-notifications-content">
          {error ? (
            <div className="mobile-modal-api-error">
              <strong>Error loading notifications:</strong> {error}
              <button
                type="button"
                onClick={() => {
                  setError(null)
                  loadNotifications()
                }}
                className="mobile-modal-retry-btn"
              >
                Retry
              </button>
            </div>
          ) : loading && notifications.length === 0 ? (
            <div className="mobile-modal-loading">Loading notifications...</div>
          ) : (
            <>
              {showSettings && (
                <div className="mobile-notifications-settings-prompt">
                  <strong>Configure notifications</strong>
                  <p className="mobile-notifications-settings-text">
                    You haven't configured any notifications yet. Tap settings below to get started.
                  </p>
                </div>
              )}

              {hasNotifications ? (
                <ul className="mobile-notifications-list">
                  {notifications.map((notification, index) => (
                    <li key={notification.notified_id || index} className="mobile-notifications-list-item">
                      <button
                        type="button"
                        onClick={() => handleDismiss(notification.notified_id)}
                        className="mobile-notifications-dismiss-btn"
                        title="Dismiss notification"
                      >
                        <FaTimes />
                      </button>
                      <div className="mobile-notifications-text">
                        <ParseLinks text={notification.text} />
                      </div>
                    </li>
                  ))}
                </ul>
              ) : (
                <div className="mobile-modal-empty">
                  {showSettings ? 'Configure notifications to get started' : 'No new notifications'}
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="mobile-modal-footer">
          <a href="/title/Settings#notifications" className="mobile-modal-footer-link">
            Notification settings
          </a>
        </div>
      </div>
    </div>
  )
}

export default MobileNotificationsModal
