import React, { useEffect, useRef } from 'react'

/**
 * GoogleAds - Renders Google AdSense banner ad
 *
 * Only renders for guests (non-logged-in users) when no_ads is false.
 * Uses useEffect to push the ad after component mounts.
 */
const GoogleAds = ({ show }) => {
  const adRef = useRef(null)
  const adPushed = useRef(false)

  useEffect(() => {
    // Only push ad once, and only if we should show it
    if (show && adRef.current && !adPushed.current) {
      try {
        // eslint-disable-next-line no-undef
        (window.adsbygoogle = window.adsbygoogle || []).push({})
        adPushed.current = true
      } catch (e) {
        console.error('AdSense error:', e)
      }
    }
  }, [show])

  if (!show) return null

  return (
    <div className="headerads">
      <center>
        <ins
          ref={adRef}
          className="adsbygoogle"
          style={{ display: 'inline-block', width: 728, height: 90 }}
          data-ad-client="ca-pub-0613380022572506"
          data-ad-slot="9636638260"
        />
      </center>
    </div>
  )
}

export default GoogleAds
