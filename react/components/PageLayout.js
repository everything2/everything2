import React from 'react'
import DocumentComponent from './DocumentComponent'
import MasonContent from './MasonContent'

/**
 * PageLayout - React content renderer for Phase 4a pages
 *
 * Phase 4a: React Page Content
 * - Renders ONLY the main content area (not full page structure)
 * - Mason still renders: header, sidebar wrapper, footer
 * - React renders: page content (into #e2-react-page-root)
 * - E2ReactRoot separately renders sidebar (into #e2-react-root)
 *
 * This component mounts into #e2-react-page-root which is inside
 * Mason's existing page structure. It does NOT render its own
 * header/sidebar/footer - those are already in the DOM from Mason.
 */
const PageLayout = ({ e2 }) => {
  // Render content based on what the backend sends:
  // - contentData: Structured data → React component
  // - contentHtml: HTML string → dangerouslySetInnerHTML

  // Case 1: Structured data (React component)
  if (e2.contentData) {
    return <DocumentComponent data={e2.contentData} user={e2.user} />
  }

  // Case 2: HTML string (Mason/delegation HTML)
  if (e2.contentHtml) {
    return <MasonContent html={e2.contentHtml} />
  }

  // Fallback: Empty content
  return (
    <div style={{ padding: '20px', textAlign: 'center', color: '#999' }}>
      No content available
    </div>
  )
}

export default PageLayout
