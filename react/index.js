import React from 'react'

import { createRoot } from 'react-dom/client'
const E2ReactRoot = React.lazy(() => import('./components/E2ReactRoot'))
const PageLayout = React.lazy(() => import('./components/PageLayout'))

// Wait for window.e2 to be available before rendering
function initReact() {
  // Check if e2 is available (set by Mason template as global variable)
  if (typeof e2 === 'undefined') {
    // Try again after a short delay
    setTimeout(initReact, 50)
    return
  }

  // Phase 4a: Check if we should render full page or just sidebar
  // If e2.reactPageMode is true, React owns the entire page structure
  // Otherwise, fall back to Phase 3 behavior (sidebar only)
  const usePageLayout = e2.reactPageMode === true

  if (usePageLayout) {
    // Phase 4a: React owns page content AND sidebar
    // Render page content into #e2-react-page-root
    const pageContainer = document.getElementById('e2-react-page-root')
    if (!pageContainer) {
      console.error('e2-react-page-root not found, cannot render PageLayout')
      return
    }

    const pageRoot = createRoot(pageContainer)
    pageRoot.render(
      <React.Suspense fallback={<div>Loading...</div>}>
        <PageLayout e2={e2} />
      </React.Suspense>
    )

    // Also render sidebar into #e2-react-root
    const sidebarContainer = document.getElementById('e2-react-root')
    if (!sidebarContainer) {
      console.error('e2-react-root not found, cannot render sidebar')
      return
    }

    const sidebarRoot = createRoot(sidebarContainer)
    sidebarRoot.render(
      <React.Suspense fallback={<div>Loading...</div>}>
        <E2ReactRoot e2={e2} />
      </React.Suspense>
    )
  } else {
    // Phase 3: React owns sidebar only (legacy behavior)
    const container = document.getElementById('e2-react-root')
    if (!container) {
      console.error('e2-react-root not found, cannot render E2ReactRoot')
      return
    }

    const root = createRoot(container)
    root.render(
      <React.Suspense fallback={<div>Loading...</div>}>
        <E2ReactRoot e2={e2} />
      </React.Suspense>
    )
  }
}

// Initialize React
initReact()
