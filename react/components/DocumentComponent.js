import React, { Suspense, lazy } from 'react'

// Lazy load document components - only loaded when needed
const WheelOfSurprise = lazy(() => import('./Documents/WheelOfSurprise'))
const SilverTrinkets = lazy(() => import('./Documents/SilverTrinkets'))

/**
 * DocumentComponent - Router for React-migrated documents
 *
 * Phase 4a: Routes structured content data to appropriate React components
 * - Accepts contentData prop with type field
 * - Dynamically loads and renders the correct React component
 * - Supports progressive migration from Mason to React
 * - Uses React.lazy() for code splitting - components only loaded when needed
 *
 * As documents are migrated from Mason/delegation to React, they are
 * registered here. Documents not yet migrated will render as Mason HTML
 * via MasonContent component instead.
 *
 * Code Splitting: Each lazy-loaded component creates a separate bundle chunk,
 * reducing the main bundle size and improving initial page load.
 */
const DocumentComponent = ({ data, user }) => {
  const { type } = data

  // Suspense fallback - shown while component is loading
  const LoadingFallback = () => (
    <div className="document-loading" style={{ padding: '20px', textAlign: 'center' }}>
      <p>Loading...</p>
    </div>
  )

  // Route to specific React component based on document type
  const renderDocument = () => {
    switch (type) {
      // Phase 4a migrations
      case 'wheel_of_surprise':
        return <WheelOfSurprise data={data} user={user} />

      case 'silver_trinkets':
        return <SilverTrinkets data={data} user={user} />

      default:
        return (
          <div className="document-error">
            <h2>Unknown Document Type</h2>
            <p>Document type "{type}" is not registered in DocumentComponent router.</p>
            <p>This document may need to be migrated to React, or the type may be incorrect.</p>
          </div>
        )
    }
  }

  return (
    <Suspense fallback={<LoadingFallback />}>
      {renderDocument()}
    </Suspense>
  )
}

export default DocumentComponent
