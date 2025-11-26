import React, { useEffect, useRef, useState } from 'react'
import NodeletContainer from '../NodeletContainer'

const Notifications = (props) => {
  const { notificationsData: initialData } = props
  const listRef = useRef(null)

  // Track current notifications (can be updated after dismiss)
  const [notificationsData, setNotificationsData] = useState(initialData)

  // Update local state when props change
  useEffect(() => {
    if (initialData) {
      setNotificationsData(initialData)
    }
  }, [initialData])

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

  const { notifications, settingsLink, showSettings } = notificationsData

  // Ensure notifications is always an array and never display empty array as "0"
  const notificationList = Array.isArray(notifications) ? notifications : []
  const hasNotifications = notificationList.length > 0
  // Convert showSettings to proper boolean to prevent rendering "0"
  const shouldShowSettings = Boolean(showSettings)

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
          // Re-render notifications using the backend's notificationsJSON htmlcode
          if (data.notifications) {
            // Fetch fresh rendered notifications from the backend
            const renderResponse = await fetch('/api/notifications/', {
              credentials: 'same-origin'
            })
            if (renderResponse.ok) {
              // For now, just remove the dismissed notification from current list
              // Full refresh would require backend to return HTML-rendered notifications
              setNotificationsData(prev => ({
                ...prev,
                notifications: prev.notifications.filter(n => n.notified_id !== notifiedId)
              }))
            }
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
        <ul ref={listRef} id="notifications_list" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {notificationList.map((notification, index) => (
            <li
              key={notification.notified_id || index}
              style={{
                padding: '8px',
                borderBottom: '1px solid #f0f0f0',
                fontSize: '12px',
                lineHeight: '1.4'
              }}
              dangerouslySetInnerHTML={{ __html: notification.html }}
            />
          ))}
        </ul>
      ) : (
        <div style={{ padding: '12px', fontSize: '12px', fontStyle: 'italic', color: '#999' }}>
          {shouldShowSettings ? 'Configure notifications to get started' : 'No new notifications'}
        </div>
      )}

      {settingsLink && (
        <div
          className="nodeletfoot"
          style={{
            borderTop: '1px solid #dee2e6',
            padding: '8px',
            marginTop: '8px',
            fontSize: '11px',
            textAlign: 'center'
          }}
          dangerouslySetInnerHTML={{ __html: settingsLink }}
        />
      )}
    </NodeletContainer>
  )
}

export default Notifications
