import { useState, useRef, useCallback, useEffect } from 'react'

/**
 * Debounced, race-free autocomplete search.
 *
 * Handles the three things every autocomplete fetch needs:
 *   1. Debounce — coalesce rapid keystrokes
 *   2. Abort in-flight request when a newer keystroke fires
 *   3. Discard stale responses that resolve after a newer query has started
 *
 * Without (2) and (3), a slow "he" response can land after a fast "hello"
 * response and overwrite the dropdown with stale suggestions (#4043).
 *
 * The caller owns input state and dropdown rendering. This hook only
 * manages the fetch lifecycle.
 *
 * @param {object} opts
 * @param {(query: string, opts: {signal: AbortSignal}) => Promise<any[]>} opts.search
 *        Async fetcher. MUST honor the abort signal so cancelled requests
 *        actually stop. The returned array becomes `results`.
 * @param {number} [opts.debounceMs=200] - Wait this long after the last
 *        triggerSearch() call before firing the fetch.
 * @param {number} [opts.minLength=2] - Queries shorter than this clear
 *        results without firing a fetch.
 *
 * @returns {{
 *   results: any[],
 *   loading: boolean,
 *   triggerSearch: (query: string) => void,
 *   clearResults: () => void,
 *   setResults: (next: any[] | ((prev: any[]) => any[])) => void,
 * }}
 */
export const useAutocompleteSearch = ({ search, debounceMs = 200, minLength = 2 }) => {
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(false)

  const timeoutRef = useRef(null)
  const abortRef = useRef(null)
  const latestQueryRef = useRef('')

  // Keep the latest search fn in a ref so triggerSearch's identity
  // doesn't churn when callers pass an inline arrow.
  const searchRef = useRef(search)
  useEffect(() => { searchRef.current = search }, [search])

  const cancelPending = useCallback(() => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current)
      timeoutRef.current = null
    }
    if (abortRef.current) {
      abortRef.current.abort()
      abortRef.current = null
    }
  }, [])

  const triggerSearch = useCallback((query) => {
    cancelPending()

    if (query.length < minLength) {
      latestQueryRef.current = query
      setResults([])
      setLoading(false)
      return
    }

    timeoutRef.current = setTimeout(async () => {
      const controller = new AbortController()
      abortRef.current = controller
      latestQueryRef.current = query
      setLoading(true)

      try {
        const data = await searchRef.current(query, { signal: controller.signal })
        if (latestQueryRef.current !== query) return
        setResults(Array.isArray(data) ? data : [])
      } catch (err) {
        if (err.name === 'AbortError') return
        console.error('Autocomplete search failed:', err)
        if (latestQueryRef.current === query) setResults([])
      } finally {
        if (latestQueryRef.current === query) setLoading(false)
      }
    }, debounceMs)
  }, [cancelPending, debounceMs, minLength])

  const clearResults = useCallback(() => {
    cancelPending()
    latestQueryRef.current = ''
    setResults([])
    setLoading(false)
  }, [cancelPending])

  useEffect(() => cancelPending, [cancelPending])

  return { results, setResults, loading, triggerSearch, clearResults }
}
