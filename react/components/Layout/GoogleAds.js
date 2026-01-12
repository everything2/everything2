import React, { useEffect, useRef } from 'react'

/**
 * GoogleAds - Renders Google AdSense banner ad
 *
 * Only renders for guests (non-logged-in users) when no_ads is false.
 * Only renders on the actual everything2.com production domain (not development/localhost).
 * Uses responsive ad format - Google automatically manages sizing for mobile.
 * Uses useEffect to push the ad after component mounts.
 */
const GoogleAds = ({ show }) => {
  const adRef = useRef(null)
  const adPushed = useRef(false)

  // Only show ads on the actual production domain (not development.everything2.com)
  const isProductionHost = typeof window !== 'undefined' &&
    (window.location.hostname === 'everything2.com' ||
     window.location.hostname === 'www.everything2.com')

  useEffect(() => {
    // Only push ad once, and only if we should show it on production
    if (show && isProductionHost && adRef.current && !adPushed.current) {
      try {
        // eslint-disable-next-line no-undef
        (window.adsbygoogle = window.adsbygoogle || []).push({})
        adPushed.current = true
      } catch (e) {
        console.error('AdSense error:', e)
      }
    }
  }, [show, isProductionHost])

  // Don't render ads on non-production hosts or when show is false
  if (!show || !isProductionHost) return null

  return (
    <div className="headerads">
      <ins
        ref={adRef}
        className="adsbygoogle"
        style={{ display: 'block' }}
        data-ad-client="ca-pub-0613380022572506"
        data-ad-slot="9636638260"
        data-ad-format="auto"
        data-full-width-responsive="true"
      />
    </div>
  )
}

export default GoogleAds
