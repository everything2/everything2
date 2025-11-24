import { useState, useEffect, useRef } from 'react'
import { useActivityDetection } from './useActivityDetection'

/**
 * Hook to poll the chatroom API for other users data
 * Uses activity detection to pause polling when user is inactive
 *
 * @param {number} pollIntervalMs - Milliseconds between polls (default: 120000 = 2 minutes)
 * @returns {Object} { otherUsersData, loading, error, refresh } - Other users state and refresh function
 */
export const useOtherUsersPolling = (pollIntervalMs = 120000) => {
  const [otherUsersData, setOtherUsersData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const pollInterval = useRef(null)

  const fetchOtherUsers = async () => {
    try {
      const response = await fetch('/api/chatroom/', {
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
      setOtherUsersData(data)
      setLoading(false)
      setError(null)
    } catch (err) {
      console.error('Failed to fetch other users:', err)
      setError(err.message)
      setLoading(false)
    }
  }

  // Manual refresh function
  const refresh = () => {
    fetchOtherUsers()
  }

  // Initial fetch
  useEffect(() => {
    fetchOtherUsers()
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
        fetchOtherUsers()
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

  return { otherUsersData, loading, error, refresh }
}
