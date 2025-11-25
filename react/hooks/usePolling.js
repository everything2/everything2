import { useState, useEffect, useRef, useCallback } from 'react'
import { useActivityDetection } from './useActivityDetection'

/**
 * Generic polling hook with activity detection and focus refresh
 *
 * @param {function} fetchFunction - Async function to fetch data
 * @param {number} pollIntervalMs - Milliseconds between polls (default: 120000 = 2 minutes)
 * @param {object} options - Additional options
 * @param {boolean} options.refreshOnFocus - Whether to refresh when page becomes visible (default: true)
 * @param {any} options.initialData - Initial data to use (skips initial API call if provided)
 * @returns {Object} { data, loading, error, refresh, setData } - State and control functions
 */
export const usePolling = (fetchFunction, pollIntervalMs = 120000, options = {}) => {
  const { refreshOnFocus = true, initialData = null } = options

  const [data, setData] = useState(initialData)
  const [loading, setLoading] = useState(!initialData)
  const [error, setError] = useState(null)
  const { isActive, isMultiTabActive } = useActivityDetection(10)
  const pollInterval = useRef(null)
  const isMounted = useRef(true)

  const fetchData = useCallback(async () => {
    if (!isMounted.current) return

    try {
      const result = await fetchFunction()
      if (isMounted.current) {
        setData(result)
        setLoading(false)
        setError(null)
      }
    } catch (err) {
      if (isMounted.current) {
        console.error('Polling fetch error:', err)
        setError(err.message)
        setLoading(false)
      }
    }
  }, [fetchFunction])

  // Manual refresh function
  const refresh = useCallback(() => {
    fetchData()
  }, [fetchData])

  // Initial fetch - only if no initial data provided
  useEffect(() => {
    if (!initialData) {
      fetchData()
    }
  }, [fetchData, initialData])

  // Polling effect
  useEffect(() => {
    // Only poll if:
    // 1. User is active (not idle for 10+ minutes)
    // 2. This is the active tab (page is in focus)
    // 3. Not currently loading
    const shouldPoll = isActive && isMultiTabActive && !loading

    if (shouldPoll) {
      pollInterval.current = setInterval(() => {
        fetchData()
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
  }, [isActive, isMultiTabActive, loading, pollIntervalMs, fetchData])

  // Focus refresh: immediately refresh when page becomes visible
  useEffect(() => {
    if (!refreshOnFocus) return

    const handleVisibilityChange = () => {
      if (!document.hidden && isActive) {
        // Page just became visible and user is active - refresh immediately
        refresh()
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [refreshOnFocus, isActive, refresh])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      isMounted.current = false
    }
  }, [])

  return { data, loading, error, refresh, setData }
}
