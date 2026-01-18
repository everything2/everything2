import React, { useEffect, useRef } from 'react'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * AD SLOT REFERENCE (ca-pub-0613380022572506):
 * - 9636638260: E2 top banner (728x90 leaderboard) - desktop header
 * - 8816650879: E2 square for zen sidebar (250x250) - sidebar
 * - 1432440697: E2 nodelet ad (160x600 skyscraper) - sidebar alternative
 * - 6277646706: E2 Responsive Ad (responsive) - mobile/in-content
 *
 * Mobile strategy:
 * - Use responsive ad (6277646706) for mobile header - auto-sizes to screen
 * - Desktop uses fixed 728x90 leaderboard
 * - Sidebar uses 250x250 square (hidden on mobile via CSS)
 */

// Ad slot configurations
export const AD_SLOTS = {
  // Desktop header - fixed leaderboard
  HEADER_DESKTOP: {
    slot: '9636638260',
    width: 728,
    height: 90,
    name: 'E2 top banner'
  },
  // Mobile header - responsive (320x50 mobile banner typical)
  HEADER_MOBILE: {
    slot: '6277646706',
    width: 320,
    height: 50,
    responsive: true,
    name: 'E2 Responsive Ad'
  },
  // Sidebar square
  SIDEBAR_SQUARE: {
    slot: '8816650879',
    width: 250,
    height: 250,
    name: 'E2 square for zen sidebar'
  },
  // Sidebar skyscraper (alternative)
  SIDEBAR_SKYSCRAPER: {
    slot: '1432440697',
    width: 160,
    height: 600,
    name: 'E2 nodelet ad'
  }
}

const AD_CLIENT = 'ca-pub-0613380022572506'

/**
 * Check if we're on a domain where ads should be shown
 * - Production: everything2.com, www.everything2.com
 * - Development: development.everything2.com (for testing ads)
 * - NOT localhost (to avoid ad errors during local dev)
 */
const isAdEnabledHost = () => {
  if (typeof window === 'undefined') return false
  const hostname = window.location.hostname
  return (
    hostname === 'everything2.com' ||
    hostname === 'www.everything2.com' ||
    hostname === 'development.everything2.com'
  )
}

/**
 * GoogleAd - Generic AdSense ad component
 *
 * Renders a specific ad slot. Supports both fixed and responsive sizes.
 * Only renders for guests on production domain.
 *
 * Props:
 * - show: boolean - whether to show the ad
 * - slot: string - ad slot ID
 * - width: number - ad width in pixels (ignored if responsive)
 * - height: number - ad height in pixels (ignored if responsive)
 * - responsive: boolean - use responsive sizing
 * - className: string - optional CSS class
 * - style: object - optional additional styles
 */
export const GoogleAd = ({ show, slot, width, height, responsive = false, className = '', style = {} }) => {
  const adRef = useRef(null)
  const adPushed = useRef(false)
  const isAdHost = isAdEnabledHost()

  useEffect(() => {
    // Only push ad once, and only on ad-enabled hosts
    if (!show || !isAdHost || !adRef.current || adPushed.current) return

    // Track retry attempts to avoid infinite loops
    let retryCount = 0
    const maxRetries = 20 // 2 seconds max (20 * 100ms)

    // Wait for the container to have a valid width before pushing the ad
    // This prevents "No slot size for availableWidth=0" errors
    const pushAdWhenReady = () => {
      const container = adRef.current?.parentElement
      if (!container) return

      // Check if container has width and is not display:none
      // For responsive ads, we only need width - height is determined by the ad
      const containerWidth = container.offsetWidth
      const computedStyle = window.getComputedStyle(container)
      const isHidden = computedStyle.display === 'none' || computedStyle.visibility === 'hidden'

      if (containerWidth > 0 && !isHidden) {
        try {
          (window.adsbygoogle = window.adsbygoogle || []).push({})
          adPushed.current = true
        } catch (e) {
          // AdSense errors are expected in development environments
          if (process.env.NODE_ENV !== 'production') {
            console.warn('AdSense error:', e)
          }
        }
      } else if (retryCount < maxRetries) {
        // Container not ready yet, try again after a short delay
        retryCount++
        setTimeout(pushAdWhenReady, 100)
      }
      // If max retries reached and still not visible, give up silently
      // (e.g., sidebar ads on mobile that are display:none)
    }

    // Use requestAnimationFrame to ensure DOM is painted before checking width
    requestAnimationFrame(pushAdWhenReady)
  }, [show, isAdHost, slot])

  if (!show || !isAdHost) return null

  // Responsive ad styling
  if (responsive) {
    return (
      <div
        className={`google-ad google-ad--responsive ${className}`.trim()}
        style={{
          width: '100%',
          minHeight: `${height}px`,
          overflow: 'hidden',
          ...style
        }}
      >
        <ins
          ref={adRef}
          className="adsbygoogle"
          style={{ display: 'block' }}
          data-ad-client={AD_CLIENT}
          data-ad-slot={slot}
          data-ad-format="horizontal"
          data-full-width-responsive="true"
        />
      </div>
    )
  }

  // Fixed size ad
  return (
    <div
      className={`google-ad ${className}`.trim()}
      style={{
        width: `${width}px`,
        height: `${height}px`,
        maxWidth: '100%',
        overflow: 'hidden',
        ...style
      }}
    >
      <ins
        ref={adRef}
        className="adsbygoogle"
        style={{
          display: 'block',
          width: `${width}px`,
          height: `${height}px`
        }}
        data-ad-client={AD_CLIENT}
        data-ad-slot={slot}
      />
    </div>
  )
}

/**
 * GoogleAds - Header banner ad (responsive for all screen sizes)
 *
 * Only renders for guests (non-logged-in users).
 * Only renders on the actual everything2.com production domain.
 *
 * Uses responsive ad format that auto-sizes to screen width.
 * This avoids issues with component switching when isMobile changes.
 */
const GoogleAds = ({ show }) => {
  // Don't render anything for logged-in users
  if (!show) return null

  const { slot } = AD_SLOTS.HEADER_MOBILE // Use responsive slot for all sizes

  return (
    <div className="headerads">
      <GoogleAd
        show={show}
        slot={slot}
        height={90}
        responsive={true}
        className="header-banner-ad"
      />
    </div>
  )
}

/**
 * SidebarAd - Square ad for sidebar (250x250)
 *
 * Designed to fit in the nodelet sidebar area.
 * Not rendered on mobile (sidebar is not shown on mobile).
 */
export const SidebarAd = ({ show }) => {
  const isMobile = useIsMobile()

  // Don't render sidebar ads on mobile - sidebar isn't visible
  if (isMobile) return null

  const { slot, width, height } = AD_SLOTS.SIDEBAR_SQUARE

  return (
    <GoogleAd
      show={show}
      slot={slot}
      width={width}
      height={height}
      className="sidebar-ad"
      style={{ margin: '0 auto' }}
    />
  )
}

/**
 * InContentAd - Ad placed between writeups (responsive)
 *
 * Uses responsive horizontal format to fit within content area.
 * Only shown for guests viewing pages with multiple writeups.
 */
export const InContentAd = ({ show }) => {
  // Don't render anything when not showing ads
  if (!show) return null

  const { slot } = AD_SLOTS.HEADER_MOBILE // Reuse responsive ad slot

  return (
    <div className="in-content-ad" data-reader-ignore="true">
      <GoogleAd
        show={show}
        slot={slot}
        height={100}
        responsive={true}
        className="in-content-ad-unit"
        style={{ margin: '20px auto', maxWidth: '728px' }}
      />
    </div>
  )
}

/**
 * FooterAd - Ad placed just before the footer (responsive)
 *
 * Uses responsive horizontal format, works on both mobile and desktop.
 * Only shown for guests.
 */
export const FooterAd = ({ show }) => {
  // Don't render anything when not showing ads
  if (!show) return null

  const { slot } = AD_SLOTS.HEADER_MOBILE // Reuse responsive ad slot

  return (
    <div className="footer-ad" data-reader-ignore="true">
      <GoogleAd
        show={show}
        slot={slot}
        height={90}
        responsive={true}
        className="footer-ad-unit"
      />
    </div>
  )
}

export default GoogleAds
