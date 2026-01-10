import React from 'react'
import DocumentComponent from './DocumentComponent'
import MasonContent from './MasonContent'
import Header from './Layout/Header'
import PageHeader from './Layout/PageHeader'
import PageActions from './PageActions'
import GoogleAds from './Layout/GoogleAds'
import E2ReactRoot from './E2ReactRoot'

/**
 * PageLayout - Unified React renderer for full page body
 *
 * Phase 6: Single React tree rendering entire body
 * - No portals needed - React owns the full body structure
 * - Renders header, ads, main content, sidebar, and footer
 * - All page structure in one component tree for shared state
 * - Supports standalone mode for fullscreen pages (e.g., chatterlight)
 */
const PageLayout = ({ e2 }) => {
  // Check if this is a standalone page (fullscreen, no header/footer/sidebar)
  const isStandalone = e2.contentData?.standalone === true

  // Determine if EpicenterZen should show (users without Epicenter nodelet)
  const showEpicenterZen = e2.epicenter?.showEpicenterZen === true

  // Show ads only for guests (e2.guest === 1 means guest user)
  const showAds = e2.guest === 1

  // Render main content based on what the backend sends
  const renderContent = () => {
    // Case 1: Structured data (React component)
    if (e2.contentData) {
      return <DocumentComponent data={e2.contentData} user={e2.user} e2={e2} />
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

  // Standalone pages render content directly without chrome
  if (isStandalone) {
    return renderContent()
  }

  // Standard page layout with header, sidebar, footer
  return (
    <>
      {/* Google Ads - only for guests */}
      <GoogleAds show={showAds} />

      {/* Header */}
      <div id="header" role="banner" aria-label="Site header" data-reader-ignore="true">
        <Header
          user={e2.user}
          epicenter={e2.epicenter}
          lastNodeId={parseInt(e2.node_id, 10) || 0}
          showEpicenterZen={showEpicenterZen}
        />
      </div>

      {/* Main wrapper with content and sidebar */}
      <div id="wrapper">
        <div id="mainbody" itemProp="mainContentOfPage">
          {/* google_ad_section_start */}
          {!e2.contentData?.hidePageHeader && (
            <PageHeader
              node={e2.node}
              pageheader={e2.pageheader}
              user={e2.user}
            >
              <PageActions />
            </PageHeader>
          )}
          {renderContent()}
          {/* google_ad_section_end */}
        </div>

        <div id="sidebar" role="complementary" aria-label="Sidebar" data-reader-ignore="true">
          <E2ReactRoot e2={e2} />
        </div>
      </div>

      {/* Footer */}
      <footer id="footer" role="contentinfo" aria-label="Site footer" data-reader-ignore="true">
        Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &copy; original author unless stated otherwise.
      </footer>
    </>
  )
}

export default PageLayout
