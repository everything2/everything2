import React, { useState, useEffect } from 'react'
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

  // Mirror e2.user as state so vote/cool/gift-shop actions that dispatch
  // window 'e2:userUpdate' events refresh the header EpicenterZen and the
  // MobileProfileMenu — not just the sidebar Epicenter (which has its own
  // listener inside E2ReactRoot).
  const [user, setUser] = useState(e2.user)
  useEffect(() => {
    const onUserUpdate = (event) => {
      const updates = event.detail
      if (!updates) return
      setUser(prev => ({ ...prev, ...updates }))
      if (window.e2?.user) Object.assign(window.e2.user, updates)
    }
    window.addEventListener('e2:userUpdate', onUserUpdate)
    return () => window.removeEventListener('e2:userUpdate', onUserUpdate)
  }, [])

  // Mirror e2.node as state so an in-place writeup type change (#4224) can
  // update the page H1 ("<e2node> (<type>)") without a refresh, via an
  // 'e2:nodeTitleUpdate' window event — same pattern as e2:userUpdate above.
  const [node, setNode] = useState(e2.node)
  useEffect(() => {
    const onNodeTitleUpdate = (event) => {
      const title = event.detail?.title
      if (!title) return
      setNode(prev => ({ ...(prev || {}), title }))
      if (window.e2?.node) window.e2.node.title = title
    }
    window.addEventListener('e2:nodeTitleUpdate', onNodeTitleUpdate)
    return () => window.removeEventListener('e2:nodeTitleUpdate', onNodeTitleUpdate)
  }, [])

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
      return <DocumentComponent data={e2.contentData} user={user} e2={e2} />
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
          user={user}
          epicenter={e2.epicenter}
          lastNodeId={parseInt(e2.node_id, 10) || 0}
          showEpicenterZen={showEpicenterZen}
          onShowAuth={() => setShowAuthModal(true)}
        />
      </div>

      {/* Main wrapper with content and sidebar - grows to fill available space */}
      <div id="wrapper">
        <div id="mainbody" itemProp="mainContentOfPage">
          {/* google_ad_section_start */}
          {!e2.contentData?.hidePageHeader && (
            <PageHeader
              node={node}
              pageheader={e2.pageheader}
              user={user}
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
          user={user}
          unreadMessages={user?.unreadMessages || 0}
          onShowAuth={() => setShowAuthModal(true)}
          chatterMessages={e2.chatterbox?.messages || []}
          chatterCount={e2.chatterbox?.messages?.length || 0}
          otherUsersData={e2.otherUsersData || null}
          otherUsersCount={e2.otherUsersData?.userCount || 0}
          currentRoom={e2.otherUsersData?.currentRoomId ?? user?.in_room ?? 0}
          publicChatterOff={!!e2.chatterbox?.publicChatterOff}
          isBorged={!!user?.borged}
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
