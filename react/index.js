import React from 'react'
import './assets/favicon.ico'

import { createRoot } from 'react-dom/client'
const E2ReactRoot = React.lazy(() => import('./components/E2ReactRoot'))

// Wait for window.e2 to be available before rendering
function initReact() {
  const container = document.getElementById('e2-react-root')
  const root = createRoot(container)

  // Check if e2 is available (set by Mason template as global variable)
  if (typeof e2 === 'undefined') {
    console.warn('e2 not available yet, waiting...')
    // Try again after a short delay
    setTimeout(initReact, 50)
    return
  }

  root.render(
    <React.StrictMode>
      <E2ReactRoot e2={e2} />
    </React.StrictMode>
  )
}

// Initialize React
initReact()
