import { useState, useEffect, useRef } from 'react'
import { useActivityDetection } from './useActivityDetection'

/**
 * Hook to poll the chatter API for new messages
 * Uses activity detection to pause polling when user is inactive
 *
 * @param {number} pollIntervalMs - Milliseconds between polls (default: 3000)
 * @returns {Object} { chatter, loading, error, refresh } - Chatter state and refresh function
 */
export const useChatterPolling = (pollIntervalMs = 3000) => {
  const [chatter, setChatter] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const lastTimestamp = useRef(null)
  const pollInterval = useRef(null)

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

  // Initial fetch
  useEffect(() => {
    fetchChatter(true)
  }, [])

  // Polling effect
  useEffect(() => {
    // Only poll if:
    // 1. User is active (not idle for 10+ minutes)
    // 2. This is the active tab (multi-tab detection)
    // 3. Not currently loading
    const shouldPoll = isActive && isMultiTabActive && !loading

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        fetchChatter(false)
      }, pollIntervalMs)
    } else {
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
  }, [isActive, isMultiTabActive, loading, pollIntervalMs])

  return { chatter, loading, error, refresh }
}
