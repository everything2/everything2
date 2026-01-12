/**
 * Breakpoint constants for responsive design
 *
 * Mobile-first approach with consistent breakpoints across the app.
 * These match the media queries used in CSS.
 */

export const BREAKPOINTS = {
  MOBILE: 767,
  TABLET: 991,
  DESKTOP: 1200
}

export const MEDIA_QUERIES = {
  mobile: `(max-width: ${BREAKPOINTS.MOBILE}px)`,
  tablet: `(min-width: ${BREAKPOINTS.MOBILE + 1}px) and (max-width: ${BREAKPOINTS.TABLET}px)`,
  desktop: `(min-width: ${BREAKPOINTS.TABLET + 1}px)`
}

export default BREAKPOINTS
