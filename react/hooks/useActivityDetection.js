import { useState, useEffect, useRef } from 'react'

/**
 * Detect user activity and tab visibility to gate polling.
 *
 * Returns three signals that consumers compose into a `shouldPoll` boolean:
 *   - isActive          : user has interacted within the last `sleepAfterMinutes`
 *                         (default 10). False when the user has wandered off.
 *   - isRecentlyActive  : user interacted within the last 60s. Controls poll
 *                         cadence — useChatterPolling polls every 45s when this
 *                         is true, 120s when not.
 *   - isTabVisible      : this tab is currently the foreground tab in its
 *                         window. Driven by `document.visibilityState` via the
 *                         `visibilitychange` event.
 *
 * The visibility signal replaced an earlier cookie-based "last active tab wins"
 * heuristic (#4061). That heuristic stopped all-but-one E2 tabs from polling
 * the moment you interacted with any of them, and the others stayed stuck on
 * stale data until the next 5s tick after you focused them again. Chromium
 * surfaced the bug more often than Firefox because it doesn't fire focus
 * events as eagerly when tabs share a window. Visibility is the right signal:
 * each tab polls independently while in the foreground, and stops when hidden.
 *
 * @param {number} sleepAfterMinutes Inactivity threshold before isActive flips
 *   to false. Default 10.
 */
export const useActivityDetection = (sleepAfterMinutes = 10) => {
  const [isActive, setIsActive] = useState(true)
  const [isRecentlyActive, setIsRecentlyActive] = useState(true)
  const [isTabVisible, setIsTabVisible] = useState(
    typeof document === 'undefined' ? true : !document.hidden
  )
  const lastActivity = useRef(Date.now())

  useEffect(() => {
    const handleActivity = () => {
      lastActivity.current = Date.now()
      // De-dupe state setters — most activity bursts hit while we're already
      // active, and triggering a render per scroll event is wasteful.
      setIsActive(prev => (prev ? prev : true))
      setIsRecentlyActive(prev => (prev ? prev : true))
    }

    const handleVisibilityChange = () => {
      setIsTabVisible(!document.hidden)
    }

    const checkInactivity = setInterval(() => {
      const now = Date.now()
      const minutesInactive = (now - lastActivity.current) / 1000 / 60
      const secondsInactive = (now - lastActivity.current) / 1000

      // Drop out of "recently active" first (controls poll cadence)
      if (secondsInactive >= 60) {
        setIsRecentlyActive(prev => (prev ? false : prev))
      }

      // Then drop out of "active" entirely (gates polling at all)
      if (minutesInactive >= sleepAfterMinutes) {
        setIsActive(prev => (prev ? false : prev))
      }
    }, 5000)

    const events = ['mousedown', 'keydown', 'scroll', 'touchstart']
    events.forEach((event) => {
      window.addEventListener(event, handleActivity, { passive: true })
    })
    document.addEventListener('visibilitychange', handleVisibilityChange)

    // Seed lastActivity from "now" — assume the user is here when the
    // component mounts, even before they've moved the mouse.
    handleActivity()

    return () => {
      clearInterval(checkInactivity)
      events.forEach((event) => {
        window.removeEventListener(event, handleActivity)
      })
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [sleepAfterMinutes])

  return { isActive, isRecentlyActive, isTabVisible }
}
