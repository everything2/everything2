import React, { useEffect, useRef } from 'react'

/**
 * MasonContent - Wrapper for Mason-generated HTML
 *
 * Phase 4a: Transitional component for legacy Mason2 content
 * - Accepts HTML string from Mason template rendering
 * - Inserts via dangerouslySetInnerHTML
 * - Re-initializes legacy JavaScript if needed
 *
 * This component allows us to progressively migrate away from Mason2
 * while keeping existing content functional during the transition.
 */
const MasonContent = ({ html }) => {
  const contentRef = useRef(null)

  useEffect(() => {
    // Re-initialize any legacy JavaScript that depends on DOM being ready
    // This is needed because Mason HTML may contain inline scripts or
    // expect certain jQuery initialization

    if (contentRef.current && window.initLegacyContent) {
      window.initLegacyContent(contentRef.current)
    }
  }, [html])

  return (
    <div
      ref={contentRef}
      className="mason-content"
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}

export default MasonContent
