import React from 'react'
import WheelOfSurprise from './Documents/WheelOfSurprise'
import SilverTrinkets from './Documents/SilverTrinkets'

/**
 * DocumentComponent - Router for React-migrated documents
 *
 * Phase 4a: Routes structured content data to appropriate React components
 * - Accepts contentData prop with type field
 * - Dynamically loads and renders the correct React component
 * - Supports progressive migration from Mason to React
 *
 * As documents are migrated from Mason/delegation to React, they are
 * registered here. Documents not yet migrated will render as Mason HTML
 * via MasonContent component instead.
 */
const DocumentComponent = ({ data, user }) => {
  const { type } = data

  // Route to specific React component based on document type
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

export default DocumentComponent
