import React, { Suspense, lazy } from 'react'

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
 * registered in the COMPONENT_MAP below. Documents not yet migrated will
 * render as Mason HTML via MasonContent component instead.
 *
 * Code Splitting: Each lazy-loaded component creates a separate bundle chunk,
 * reducing the main bundle size and improving initial page load.
 *
 * Scalability: Component map pattern scales to hundreds of documents without
 * creating an unwieldy switch statement.
 */

// Component registry - maps document type to lazy-loaded React component
// Add new migrated documents here as they are converted from Mason to React
const COMPONENT_MAP = {
  // Phase 4a migrations
  wheel_of_surprise: lazy(() => import('./Documents/WheelOfSurprise')),
  silver_trinkets: lazy(() => import('./Documents/SilverTrinkets')),
  golden_trinkets: lazy(() => import('./Documents/GoldenTrinkets')),
  about_nobody: lazy(() => import('./Documents/AboutNobody')),
  e2_staff: lazy(() => import('./Documents/E2Staff')),
  what_to_do_if_e2_goes_down: lazy(() => import('./Documents/WhatToDoIfE2GoesDown')),
  list_html_tags: lazy(() => import('./Documents/ListHtmlTags')),
  your_gravatar: lazy(() => import('./Documents/YourGravatar')),
  oblique_strategies_garden: lazy(() => import('./Documents/ObliqueStrategiesGarden')),
  manna_from_heaven: lazy(() => import('./Documents/MannaFromHeaven')),
  everything_s_obscure_writeups: lazy(() => import('./Documents/EverythingObscureWriteups')),
  nodeshells: lazy(() => import('./Documents/Nodeshells')),

  // Numbered nodelist pages (reusable NodeList component)
  '25': lazy(() => import('./Documents/NodeList')),
  everything_new_nodes: lazy(() => import('./Documents/NodeList')),
  e2n: lazy(() => import('./Documents/NodeList')),
  enn: lazy(() => import('./Documents/NodeList')),
  ekn: lazy(() => import('./Documents/NodeList')),

  // Text generators (reusable RandomText component)
  fezisms_generator: lazy(() => import('./Documents/RandomText')),
  piercisms_generator: lazy(() => import('./Documents/RandomText')),

  // Utility tools
  wharfinger_s_linebreaker: lazy(() => import('./Documents/WharfingerLinebreaker'))

  // Add new documents here as they are migrated
  // Format: document_type: lazy(() => import('./Documents/ComponentName'))
}

const DocumentComponent = ({ data, user }) => {
  const { type } = data

  // Suspense fallback - shown while component is loading
  const LoadingFallback = () => (
    <div className="document-loading" style={{ padding: '20px', textAlign: 'center' }}>
      <p>Loading...</p>
    </div>
  )

  // Look up component in registry
  const Component = COMPONENT_MAP[type]

  // Render component if found, otherwise show error
  const renderDocument = () => {
    if (Component) {
      return <Component data={data} user={user} />
    }

    return (
      <div className="document-error">
        <h2>Unknown Document Type</h2>
        <p>
          Document type "{type}" is not registered in DocumentComponent router.
        </p>
        <p>
          This document may need to be migrated to React, or the type may be incorrect.
        </p>
      </div>
    )
  }

  return <Suspense fallback={<LoadingFallback />}>{renderDocument()}</Suspense>
}

export default DocumentComponent
