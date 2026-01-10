import React from 'react'
import Modal from 'react-modal'

import { createRoot } from 'react-dom/client'
import { setupGlobalErrorHandlers } from './utils/reportClientError'
import { setupAnalytics } from './utils/analytics'

import PageLayout from './components/PageLayout'

// Set up global error handlers for uncaught errors
setupGlobalErrorHandlers()

// Set lastnode_id cookie for softlink tracking
// This enables softlink creation without polluting URLs with query params
// Only for logged-in users - guests don't create softlinks
function setLastNodeCookie(nodeId) {
  if (nodeId && nodeId > 0) {
    // Set cookie with path=/ so it's sent on all requests
    // SameSite=Lax allows the cookie to be sent on navigation
    // Max-Age of 1 hour is sufficient for typical browsing sessions
    document.cookie = `lastnode_id=${nodeId}; path=/; SameSite=Lax; max-age=3600`
  }
}

// Set up click handler to track intentional navigation for softlinks
// Only links clicked inside #mainbody should create softlinks
// Nodelet/sidebar links are casual browsing, not topic connections
// Uses event delegation on document since #mainbody is rendered by React
function setupSoftlinkTracking(nodeId, isGuest) {
  if (isGuest || !nodeId) return

  document.addEventListener('click', (event) => {
    // Check if the click was on a link inside mainbody
    const link = event.target.closest('a')
    if (!link || !link.href) return

    // Only track clicks inside mainbody (not sidebar/nodelets)
    const mainbody = link.closest('#mainbody')
    if (mainbody) {
      // Set the cookie so the next page knows where we came from
      setLastNodeCookie(nodeId)
    }
  })
}

// Wait for window.e2 to be available before rendering
function initReact() {
  // Check if e2 is available (set by Mason template as global variable)
  if (typeof e2 === 'undefined') {
    // Try again after a short delay
    setTimeout(initReact, 50)
    return
  }

  // Set up softlink tracking for intentional navigation
  // Only tracks clicks on links inside main content, not nodelets
  setupSoftlinkTracking(e2.node_id, e2.guest)

  // Initialize Google Analytics 4 tracking
  setupAnalytics(e2.guest === 1)

  // Find the page root container
  const pageContainer = document.getElementById('e2-react-page-root')
  if (!pageContainer) {
    console.error('e2-react-page-root not found, cannot render PageLayout')
    return
  }

  // Set app element for react-modal accessibility
  // Use the page container since React renders the entire body
  Modal.setAppElement(pageContainer)

  // Render PageLayout - single React tree rendering entire page body
  const pageRoot = createRoot(pageContainer)
  pageRoot.render(<PageLayout e2={e2} />)
}

// Initialize React
initReact()
