import { useState, useEffect, useRef } from 'react'
import { useActivityDetection } from './useActivityDetection'

/**
 * Hook to poll the chatter API for new messages
 * Uses activity detection to adjust polling rate and pause when inactive
 *
 * @param {number} activeIntervalMs - Milliseconds between polls when user is active (default: 45000)
 * @param {number} idleIntervalMs - Milliseconds between polls when user is idle (default: 120000)
 * @param {boolean} nodeletIsOpen - Whether the nodelet is expanded (default: true)
 * @param {number} currentRoom - Current room ID to detect room changes (default: null)
 * @param {array} initialChatter - Initial chatter messages to use (skips initial API call if provided)
 * @returns {Object} { chatter, loading, error, refresh } - Chatter state and refresh function
 */
export const useChatterPolling = (activeIntervalMs = 45000, idleIntervalMs = 120000, nodeletIsOpen = true, currentRoom = null, initialChatter = null) => {
  const [chatter, setChatter] = useState(initialChatter || [])
  const [loading, setLoading] = useState(!initialChatter)
  const [error, setError] = useState(null)
  const { isActive, isRecentlyActive, isMultiTabActive } = useActivityDetection(10)
  const lastTimestamp = useRef(null)
  const pollInterval = useRef(null)
  const missedUpdate = useRef(false)
  const previousRoom = useRef(currentRoom)

  // Set initial timestamp from initialChatter if provided
  useEffect(() => {
    if (initialChatter && initialChatter.length > 0) {
      lastTimestamp.current = initialChatter[0].timestamp
    }
  }, [])

  const fetchChatter = async (isInitial = false) => {
    try {
      // Build URL with optional since parameter for incremental updates
      let url = '/api/chatter/'
      const params = new URLSearchParams()

      if (!isInitial && lastTimestamp.current) {
        params.append('since', lastTimestamp.current)
      } else {
        params.append('limit', '30')
      }

      // Add room parameter if provided (including 0 for "outside")
      if (currentRoom !== null) {
        params.append('room', currentRoom)
      }

      if (params.toString()) {
        url += '?' + params.toString()
      }

      const response = await fetch(url, {
        headers: {
          'X-Ajax-Idle': '1',
          'Accept': 'application/json'
        },
        credentials: 'same-origin'
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const data = await response.json()

      if (isInitial) {
        // Initial load: replace all chatter
        setChatter(data)
        if (data.length > 0) {
          lastTimestamp.current = data[0].timestamp
        }
      } else {
        // Incremental update: prepend new messages
        if (data.length > 0) {
          setChatter((prev) => [...data, ...prev])
          lastTimestamp.current = data[0].timestamp
        }
      }

      setLoading(false)
      setError(null)
    } catch (err) {
      console.error('Failed to fetch chatter:', err)
      setError(err.message)
      setLoading(false)
    }
  }

  // Manual refresh function
  const refresh = () => {
    fetchChatter(true)
  }

  // Initial fetch - only if no initial data provided
  useEffect(() => {
    if (!initialChatter) {
      fetchChatter(true)
    }
  }, [])

  // Focus refresh: immediately refresh when page becomes visible
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && isActive) {
        // Page just became visible and user is active - refresh immediately
        fetchChatter(false)
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [isActive])

  // Polling effect
  useEffect(() => {
    // Only poll if:
    // 1. User is active (not idle for 10+ minutes)
    // 2. This is the active tab (page is in focus)
    // 3. Not currently loading
    // 4. Nodelet is expanded (not collapsed)
    const shouldPoll = isActive && isMultiTabActive && !loading && nodeletIsOpen

    if (shouldPoll) {
      // Use active interval (45s) if recently active, idle interval (2m) otherwise
      const currentInterval = isRecentlyActive ? activeIntervalMs : idleIntervalMs

      pollInterval.current = setInterval(() => {
        fetchChatter(false)
      }, currentInterval)
    } else {
      // If we're not polling because nodelet is collapsed, mark that we missed updates
      if (isActive && isMultiTabActive && !loading && !nodeletIsOpen) {
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
  }, [isActive, isRecentlyActive, isMultiTabActive, loading, nodeletIsOpen, activeIntervalMs, idleIntervalMs])

  // Uncollapse detection: refresh immediately when nodelet is uncollapsed after missing updates
  useEffect(() => {
    if (nodeletIsOpen && missedUpdate.current) {
      missedUpdate.current = false
      fetchChatter(false)
    }
  }, [nodeletIsOpen])

  // Room change detection: refresh immediately when user changes rooms
  useEffect(() => {
    if (currentRoom !== null && previousRoom.current !== null && currentRoom !== previousRoom.current) {
      // Room changed from one room to another - fetch new chatter immediately
      fetchChatter(true)
    } else if (currentRoom !== null && previousRoom.current === null) {
      // Room just became available (was null, now has value) - fetch with room filter
      fetchChatter(true)
    }
    previousRoom.current = currentRoom
  }, [currentRoom])

  return { chatter, loading, error, refresh }
}
