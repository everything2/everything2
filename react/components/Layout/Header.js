import React from 'react'
import SearchBar from './SearchBar'
import EpicenterZen from './EpicenterZen'

/**
 * Header - Site header component
 *
 * Contains the E2 logo, search bar, and user links (for users without Epicenter nodelet).
 *
 * Props:
 * - user: Current user object { node_id, title, guest, admin, editor, etc. }
 * - epicenter: Epicenter data { serverTime, userSettingsId, etc. }
 * - lastNodeId: Last node ID for softlink tracking
 * - showEpicenterZen: Whether to show the compact linkbar (for users without Epicenter nodelet)
 */
const Header = ({
  user,
  epicenter,
  lastNodeId = 0,
  showEpicenterZen = false
}) => {
  const isGuest = user?.guest

  return (
    <>
      {/* EpicenterZen linkbar - rendered outside header padding for flush edges */}
      {showEpicenterZen && !isGuest && (
        <EpicenterZen user={user} epicenter={epicenter} />
      )}

      <header style={styles.header} role="banner">
        <div style={styles.headerMain}>
          {/* Logo - fixed left */}
          <div style={styles.logo} id="e2logo">
            <a href="/" style={styles.logoLink}>
              Everything<span className="logo-accent">2</span>
            </a>
          </div>

          {/* Spacer to push search toward center */}
          <div style={styles.spacer} />

          {/* Search form - centered, but pushes right if needed */}
          <div style={styles.searchSection} id="searchform">
            <SearchBar
              initialValue=""
              lastNodeId={lastNodeId}
              showOptions={true}
              compact={false}
            />
          </div>

          {/* Spacer for balance */}
          <div style={styles.spacer} />
        </div>
      </header>
    </>
  )
}

const styles = {
  header: {
    // backgroundColor and color inherited from CSS (#header rules in theme stylesheets)
    padding: '6px 15px',
    position: 'relative',
    zIndex: 100
  },
  headerMain: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-start',
    gap: 15
  },
  spacer: {
    flex: 1,
    minWidth: 0
  },
  searchSection: {
    flex: '0 1 400px',
    minWidth: 200
  },
  logo: {
    fontFamily: 'Georgia, serif',
    fontSize: 24,
    fontWeight: 'bold',
    lineHeight: 1
  },
  logoLink: {
    // color and textDecoration inherited from CSS (#e2logo a rules in theme stylesheets)
  }
  // Note: .logo-accent color is set via CSS (theme-specific)
  // Kernel Blue uses #3bb5c3 (cyan), other themes inherit from header
}

export default Header
