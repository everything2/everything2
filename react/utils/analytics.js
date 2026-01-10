/**
 * Google Analytics 4 utilities
 *
 * Handles GA4 initialization, user tracking, and ad blocker detection.
 * The gtag.js script is loaded in the HTML template (zen.mc/container.pm).
 */

// GA4 Property ID
const GA4_PROPERTY_ID = 'G-2GBBBF9ZDK'

// Initialize dataLayer for gtag
window.dataLayer = window.dataLayer || []

function gtag() {
  window.dataLayer.push(arguments)
}

// Make gtag available globally for any components that need it
window.gtag = gtag

/**
 * Initialize GA4 with user login status
 * @param {boolean} isGuest - Whether the current user is a guest
 */
export function initGA4(isGuest) {
  const userLoginStatus = isGuest ? 'guest' : 'logged_in'

  gtag('js', new Date())
  gtag('config', GA4_PROPERTY_ID, {
    'user_login_status': userLoginStatus
  })

  return userLoginStatus
}

/**
 * Detect ad blocker status and send GA4 event
 * Should be called after page load with a delay to allow ads to render
 * @param {string} userLoginStatus - 'logged_in' or 'guest'
 */
export function detectAdBlocker(userLoginStatus) {
  let adStatus = 'no_ad_slot' // default: no ad element on page
  const adElement = document.querySelector('.adsbygoogle')

  if (adElement) {
    // Ad slot exists, check if it rendered
    if (adElement.offsetHeight > 0 && adElement.querySelector('iframe')) {
      adStatus = 'ad_shown'
    } else if (typeof window.adsbygoogle === 'undefined') {
      adStatus = 'blocked_script' // AdSense script blocked
    } else {
      adStatus = 'blocked_render' // Script loaded but ad didn't render
    }
  }

  gtag('event', 'ad_check', {
    'ad_status': adStatus,
    'user_type': userLoginStatus
  })

  return adStatus
}

/**
 * Initialize all GA4 tracking
 * Call this once when React app initializes
 * @param {boolean} isGuest - Whether the current user is a guest
 */
export function setupAnalytics(isGuest) {
  const userLoginStatus = initGA4(isGuest)

  // Detect ad blocker after page load with delay for ads to render
  if (document.readyState === 'complete') {
    setTimeout(() => detectAdBlocker(userLoginStatus), 3000)
  } else {
    window.addEventListener('load', () => {
      setTimeout(() => detectAdBlocker(userLoginStatus), 3000)
    })
  }
}

/**
 * Send a custom GA4 event
 * @param {string} eventName - Name of the event
 * @param {object} eventParams - Event parameters
 */
export function trackEvent(eventName, eventParams = {}) {
  gtag('event', eventName, eventParams)
}

export default {
  setupAnalytics,
  initGA4,
  detectAdBlocker,
  trackEvent
}
