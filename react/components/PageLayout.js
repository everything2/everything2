import React, { useState } from 'react'
import DocumentComponent from './DocumentComponent'
import MasonContent from './MasonContent'
import Header from './Layout/Header'
import PageHeader from './Layout/PageHeader'
import PageActions from './PageActions'
import GoogleAds, { FooterAd } from './Layout/GoogleAds'
import E2ReactRoot from './E2ReactRoot'
import MobileBottomNav from './Layout/MobileBottomNav'
import AuthModal from './Layout/AuthModal'
import { useIsMobile } from '../hooks/useMediaQuery'

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
  // Mobile detection for responsive layout
  const isMobile = useIsMobile()

  // Auth modal state (shared between header and bottom nav)
  const [showAuthModal, setShowAuthModal] = useState(false)

  // Check if this is a standalone page (fullscreen, no header/footer/sidebar)
  const isStandalone = e2.contentData?.standalone === true

  // Determine if EpicenterZen should show (users without Epicenter nodelet)
  const showEpicenterZen = e2.epicenter?.showEpicenterZen === true

  // Show ads only for guests (e2.guest === 1 means guest user)
  const showAds = e2.guest === 1

  // User is a guest if e2.guest === 1
  const isGuest = e2.guest === 1

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
      <div className="page-content-empty">
        No content available
      </div>
    )
  }

  // Standalone pages render content directly without chrome
  if (isStandalone) {
    return renderContent()
  }

  // Page wrapper class - adds mobile padding for fixed bottom nav
  const wrapperClass = isMobile
    ? 'page-wrapper page-wrapper--mobile'
    : 'page-wrapper'

  // Standard page layout with header, sidebar, footer
  return (
    <div className={wrapperClass}>
      {/* Google Ads - only for guests */}
      <GoogleAds show={showAds} />

      {/* Header */}
      <div id="header" role="banner" aria-label="Site header" data-reader-ignore="true">
        <Header
          user={e2.user}
          epicenter={e2.epicenter}
          lastNodeId={parseInt(e2.node_id, 10) || 0}
          showEpicenterZen={showEpicenterZen}
          onShowAuth={() => setShowAuthModal(true)}
        />
      </div>

      {/* Main wrapper with content and sidebar - grows to fill available space */}
      <div id="wrapper" style={{ flex: 1 }}>
        <div id="mainbody" itemProp="mainContentOfPage">
          {/* google_ad_section_start */}
          {!e2.contentData?.hidePageHeader && (
            <PageHeader
              node={e2.node}
              pageheader={e2.pageheader}
              user={e2.user}
              feedUrl={e2.contentData?.feed_url}
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

      {/* Footer ad - just before footer, only for guests */}
      <FooterAd show={showAds} />

      {/* Footer - stays at bottom */}
      <footer id="footer" role="contentinfo" aria-label="Site footer" data-reader-ignore="true">
        Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &copy; original author unless stated otherwise.
      </footer>

      {/* Mobile bottom navigation - only shown on mobile */}
      {isMobile && (
        <MobileBottomNav
          user={e2.user}
          unreadMessages={e2.user?.unreadMessages || 0}
          onShowAuth={() => setShowAuthModal(true)}
          chatterMessages={e2.chatterbox?.messages || []}
          chatterCount={e2.chatterbox?.messages?.length || 0}
          otherUsersData={e2.otherUsersData || null}
          otherUsersCount={e2.otherUsersData?.userCount || 0}
          currentRoom={e2.otherUsersData?.currentRoomId ?? e2.user?.in_room ?? 0}
          publicChatterOff={!!e2.chatterbox?.publicChatterOff}
          isBorged={!!e2.user?.borged}
          notificationsData={e2.notificationsData || null}
          notificationsCount={e2.notificationsData?.notifications?.length || 0}
        />
      )}

      {/* Auth modal - shared between mobile and desktop */}
      {showAuthModal && (
        <AuthModal
          onClose={() => setShowAuthModal(false)}
          useRecaptcha={e2.recaptcha?.enabled === true}
          recaptchaKey={e2.recaptcha?.publicKey || ''}
        />
      )}
    </div>
  )
}

export default PageLayout
