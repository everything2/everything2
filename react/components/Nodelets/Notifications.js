import React, { useEffect, useRef, useState, useCallback } from 'react'
import NodeletContainer from '../NodeletContainer'
import ParseLinks from '../ParseLinks'
import { useActivityDetection } from '../../hooks/useActivityDetection'

const Notifications = (props) => {
  const { notificationsData: initialData } = props
  const listRef = useRef(null)
  const pollInterval = useRef(null)
  const missedUpdate = useRef(false)
  const { isActive, isMultiTabActive } = useActivityDetection(10)

  // Track current notifications (can be updated after dismiss)
  const [notificationsData, setNotificationsData] = useState(initialData)
  const [loading, setLoading] = useState(false)

  // Update local state when props change (only if new data exists)
  // DO NOT update if initialData is undefined/null (happens on periodic refresh)
  useEffect(() => {
    if (initialData && initialData.notifications) {
      setNotificationsData(initialData)
    }
  }, [initialData])

  // Load notifications from API
  const loadNotifications = useCallback(async () => {
    if (loading) return

    setLoading(true)
    try {
      const response = await fetch('/api/notifications/', {
        credentials: 'include',
        headers: {
          'X-Ajax-Idle': '1'
        }
      })

      if (response.ok) {
        const data = await response.json()
        setNotificationsData(data)
      }
    } catch (error) {
      console.error('Error loading notifications:', error)
    } finally {
      setLoading(false)
    }
  }, [loading])

  // Polling effect - refresh every 2 minutes when active and nodelet is expanded
  useEffect(() => {
    const shouldPoll = isActive && isMultiTabActive && !loading && props.nodeletIsOpen

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        loadNotifications()
      }, 120000) // 2 minutes
    } else {
      // If we're not polling because nodelet is collapsed, mark that we missed updates
      if (isActive && isMultiTabActive && !loading && !props.nodeletIsOpen) {
        missedUpdate.current = true
      }

      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }

    return () => {
      if (pollInterval.current) {
        clearInterval(pollInterval.current)
        pollInterval.current = null
      }
    }
  }, [isActive, isMultiTabActive, loading, props.nodeletIsOpen, loadNotifications])

  // Uncollapse detection: refresh immediately when nodelet is uncollapsed after missing updates
  useEffect(() => {
    if (props.nodeletIsOpen && missedUpdate.current) {
      missedUpdate.current = false
      loadNotifications()
    }
  }, [props.nodeletIsOpen, loadNotifications])

  // Focus refresh: immediately refresh when page becomes visible
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && isActive) {
        loadNotifications()
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isActive, loadNotifications])

  if (!notificationsData) {
    return (
      <NodeletContainer
        id={props.id}
      title="Notifications"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <div style={{ padding: '12px', fontSize: '12px', fontStyle: 'italic', color: '#999' }}>
          No notifications configured
        </div>
      </NodeletContainer>
    )
  }

  const { notifications, showSettings } = notificationsData

  // Ensure notifications is always an array and never display empty array as "0"
  const notificationList = Array.isArray(notifications) ? notifications : []
  const hasNotifications = notificationList.length > 0
  // Convert showSettings to proper boolean to prevent rendering "0"
  const shouldShowSettings = Boolean(showSettings)

  // Settings link generated purely in React (no server-rendered HTML)
  const settingsUrl = '/node/superdoc/Nodelet+Settings#notificationsnodeletsettings'

  // Handle dismiss button clicks
  useEffect(() => {
    if (!listRef.current) return

    const handleDismiss = async (event) => {
      const target = event.target
      if (!target.classList.contains('dismiss')) return

      event.preventDefault()

      // Extract notified_id from the dismiss button's class (format: "dismiss notified_123")
      const classMatch = target.className.match(/notified_(\d+)/)
      if (!classMatch) return

      const notifiedId = parseInt(classMatch[1], 10)

      try {
        const response = await fetch('/api/notifications/dismiss', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ notified_id: notifiedId }),
          credentials: 'same-origin'
        })

        if (response.ok) {
          const data = await response.json()
          // Update notifications with server response (contains updated HTML-rendered notifications)
          if (data.notifications) {
            setNotificationsData(prev => ({
              ...prev,
              notifications: data.notifications
            }))
          }
        } else {
          console.error('Failed to dismiss notification:', await response.text())
        }
      } catch (error) {
        console.error('Error dismissing notification:', error)
      }
    }

    listRef.current.addEventListener('click', handleDismiss)
    return () => {
      if (listRef.current) {
        listRef.current.removeEventListener('click', handleDismiss)
      }
    }
  }, [notificationList])

  return (
    <NodeletContainer
      id={props.id}
      title="Notifications"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      {shouldShowSettings && (
        <div
          style={{
            backgroundColor: '#fffbdd',
            border: '1px solid #e8e3a8',
            borderRadius: '4px',
            padding: '12px',
            marginBottom: '12px',
            fontSize: '12px'
          }}
        >
          <strong>Configure notifications</strong>
          <p style={{ margin: '8px 0 0 0', fontSize: '11px' }}>
            You haven't configured any notifications yet. Click the settings link below to get started.
          </p>
        </div>
      )}

      {hasNotifications ? (
        <ul ref={listRef} id="notifications_list">
          {notificationList.map((notification, index) => (
            <li
              key={notification.notified_id || index}
              className={`notified_${notification.notified_id}`}
            >
              <button
                className={`dismiss notified_${notification.notified_id}`}
                style={{
                  border: 'none',
                  background: 'none',
                  cursor: 'pointer',
                  padding: 0,
                  fontSize: '14px',
                  color: '#666',
                  lineHeight: '1',
                  fontWeight: 'bold',
                  marginRight: '2px'
                }}
                title="dismiss notification"
              >
                ×
              </button>
              <ParseLinks text={notification.text} />
            </li>
          ))}
        </ul>
      ) : (
        <div style={{ padding: '12px', fontSize: '12px', fontStyle: 'italic', color: '#999' }}>
          {shouldShowSettings ? 'Configure notifications to get started' : 'No new notifications'}
        </div>
      )}

      <div
        className="nodeletfoot"
        style={{
          borderTop: '1px solid #dee2e6',
          padding: '8px',
          marginTop: '8px',
          fontSize: '11px',
          textAlign: 'center'
        }}
      >
        <a href={settingsUrl}>Notification settings</a>
      </div>
    </NodeletContainer>
  )
}

export default Notifications
