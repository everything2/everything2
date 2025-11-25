import { useState, useEffect, useRef } from 'react'

/**
 * Hook to detect user activity and implement sleep/wake behavior
 * for polling operations. Monitors mouse, keyboard, scroll, and touch
 * events to determine if the user is active.
 *
 * @param {number} sleepAfterMinutes - Minutes of inactivity before going to sleep (default: 10)
 * @returns {Object} { isActive, isRecentlyActive, isMultiTabActive } - Activity state
 */
export const useActivityDetection = (sleepAfterMinutes = 10) => {
  const [isActive, setIsActive] = useState(true)
  const [isRecentlyActive, setIsRecentlyActive] = useState(true)
  const [isMultiTabActive, setIsMultiTabActive] = useState(true)
  const lastActivity = useRef(Date.now())
  const tabId = useRef(Math.random().toString(36).substr(2, 9))

  useEffect(() => {
    const handleActivity = () => {
      lastActivity.current = Date.now()
      setIsActive(true)
      setIsRecentlyActive(true)

      // Multi-tab detection: mark this tab as active
      document.cookie = `lastActiveWindow=${tabId.current}; path=/`
    }

    const checkInactivity = setInterval(() => {
      const now = Date.now()
      const minutesInactive = (now - lastActivity.current) / 1000 / 60
      const secondsInactive = (now - lastActivity.current) / 1000

      // Recently active = activity within last 60 seconds
      if (secondsInactive >= 60) {
        setIsRecentlyActive(false)
      }

      // Check if this tab should sleep due to inactivity
      if (minutesInactive >= sleepAfterMinutes) {
        setIsActive(false)
      }

      // Check if another tab is active
      const cookies = document.cookie.split(';').reduce((acc, cookie) => {
        const [key, value] = cookie.trim().split('=')
        acc[key] = value
        return acc
      }, {})

      const lastActiveWindow = cookies.lastActiveWindow
      setIsMultiTabActive(!lastActiveWindow || lastActiveWindow === tabId.current)
    }, 5000) // Check every 5 seconds

    // Listen for user activity events
    const events = ['mousedown', 'keydown', 'scroll', 'touchstart']
    events.forEach((event) => {
      window.addEventListener(event, handleActivity, { passive: true })
    })

    // Initial activity marker
    handleActivity()

    // Cleanup
    return () => {
      clearInterval(checkInactivity)
      events.forEach((event) => {
        window.removeEventListener(event, handleActivity)
      })
    }
  }, [sleepAfterMinutes])

  return { isActive, isRecentlyActive, isMultiTabActive }
}
