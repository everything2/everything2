import { useState, useEffect } from 'react'
import { MEDIA_QUERIES } from '../utils/breakpoints'

/**
 * Hook to detect if a media query matches
 * @param {string} query - CSS media query string
 * @returns {boolean} - Whether the query matches
 */
export const useMediaQuery = (query) => {
  const [matches, setMatches] = useState(
    () => typeof window !== 'undefined' && window.matchMedia(query).matches
  )

  useEffect(() => {
    if (typeof window === 'undefined') return

    const mql = window.matchMedia(query)
    const handler = (e) => setMatches(e.matches)

    // Set initial value
    setMatches(mql.matches)

    // Listen for changes
    mql.addEventListener('change', handler)
    return () => mql.removeEventListener('change', handler)
  }, [query])

  return matches
}

/**
 * Convenience hook for mobile breakpoint
 * @returns {boolean} - True if viewport is mobile width (<=767px)
 */
export const useIsMobile = () => useMediaQuery(MEDIA_QUERIES.mobile)

/**
 * Convenience hook for tablet breakpoint
 * @returns {boolean} - True if viewport is tablet width (768-991px)
 */
export const useIsTablet = () => useMediaQuery(MEDIA_QUERIES.tablet)

/**
 * Convenience hook for desktop breakpoint
 * @returns {boolean} - True if viewport is desktop width (>=992px)
 */
export const useIsDesktop = () => useMediaQuery(MEDIA_QUERIES.desktop)

export default useMediaQuery
