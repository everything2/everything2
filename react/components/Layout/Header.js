import React from 'react'
import SearchBar from './SearchBar'
import EpicenterZen from './EpicenterZen'
import E2Logo from './E2Logo'
import MobileProfileMenu from './MobileProfileMenu'
import { useIsMobile } from '../../hooks/useMediaQuery'

/**
 * Header - Site header component
 *
 * Contains the E2 logo, search bar, and user links (for users without Epicenter nodelet).
 * On mobile, shows compact "E2" logo, search bar takes center stage, and Sign In button.
 *
 * Props:
 * - user: Current user object { node_id, title, guest, admin, editor, etc. }
 * - epicenter: Epicenter data { serverTime, userSettingsId, etc. }
 * - lastNodeId: Last node ID for softlink tracking
 * - showEpicenterZen: Whether to show the compact linkbar (for users without Epicenter nodelet)
 * - onShowAuth: Callback to show auth modal (optional, for mobile)
 */
const Header = ({
  user,
  epicenter,
  lastNodeId = 0,
  showEpicenterZen = false,
  onShowAuth
}) => {
  const isGuest = user?.guest
  const isMobile = useIsMobile()

  // Mobile header layout
  if (isMobile) {
    return (
      <header className="e2-header-mobile" role="banner">
        {/* Compact E2 logo - SVG for better performance (saves 24KB font file) */}
        <a href="/" className="e2-header-mobile-logo e2-logo" id="e2logo-mobile">
          <E2Logo size={28} />
        </a>

        {/* Search bar - takes center stage */}
        <div className="e2-header-mobile-search" id="searchform">
          <SearchBar
            initialValue=""
            lastNodeId={lastNodeId}
            showOptions={false}
            compact={true}
          />
        </div>

        {/* Auth/User section */}
        <div className="e2-header-mobile-auth">
          {isGuest ? (
            <button
              type="button"
              className="e2-header-signin-btn"
              onClick={onShowAuth}
            >
              Sign In
            </button>
          ) : (
            <MobileProfileMenu user={user} />
          )}
        </div>
      </header>
    )
  }

  // Desktop header layout
  return (
    <>
      {/* EpicenterZen linkbar - rendered outside header padding for flush edges */}
      {showEpicenterZen && !isGuest && (
        <EpicenterZen user={user} epicenter={epicenter} />
      )}

      <header className="e2-header" role="banner">
        <div className="e2-header-main">
          {/* Logo - fixed left */}
          <div className="e2-header-logo" id="e2logo">
            <a href="/">
              Everything<span className="logo-accent">2</span>
            </a>
          </div>

          {/* Spacer to push search toward center */}
          <div className="e2-header-spacer" />

          {/* Search form - centered, but pushes right if needed */}
          <div className="e2-header-search" id="searchform">
            <SearchBar
              initialValue=""
              lastNodeId={lastNodeId}
              showOptions={true}
              compact={false}
            />
          </div>

          {/* Spacer for balance */}
          <div className="e2-header-spacer" />
        </div>
      </header>
    </>
  )
}

export default Header
