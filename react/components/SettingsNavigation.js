import React, { useRef, useState, useEffect, useCallback } from 'react'

/**
 * SettingsNavigation - Navigation tabs for the unified Settings page
 *
 * Provides tab navigation between Settings, Advanced, Nodelets, Notifications,
 * Admin (editors), Edit Profile, and View Profile.
 *
 * On mobile, tabs are horizontally scrollable with fade indicators showing
 * when more content is available in either direction.
 *
 * Props:
 * - activeTab: Current active tab ('settings', 'advanced', 'nodelets', 'notifications', 'admin', 'profile')
 * - onTabChange: Callback for tab changes
 * - username: Current user's username for profile links
 * - showAdminTab: Whether to show the Admin tab (editors only)
 */
const SettingsNavigation = ({
  activeTab,
  onTabChange,
  username,
  showAdminTab = false
}) => {
  const scrollRef = useRef(null)
  const [canScrollLeft, setCanScrollLeft] = useState(false)
  const [canScrollRight, setCanScrollRight] = useState(false)

  // Check scroll position and update indicators
  const updateScrollIndicators = useCallback(() => {
    const el = scrollRef.current
    if (!el) return

    const { scrollLeft, scrollWidth, clientWidth } = el
    setCanScrollLeft(scrollLeft > 5)
    setCanScrollRight(scrollLeft < scrollWidth - clientWidth - 5)
  }, [])

  // Set up scroll listener
  useEffect(() => {
    const el = scrollRef.current
    if (!el) return

    updateScrollIndicators()
    el.addEventListener('scroll', updateScrollIndicators)
    window.addEventListener('resize', updateScrollIndicators)

    return () => {
      el.removeEventListener('scroll', updateScrollIndicators)
      window.removeEventListener('resize', updateScrollIndicators)
    }
  }, [updateScrollIndicators])

  // Scroll active tab into view on mount
  useEffect(() => {
    const el = scrollRef.current
    if (!el) return

    const activeButton = el.querySelector('[data-active="true"]')
    if (activeButton) {
      activeButton.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' })
    }
  }, [activeTab])

  // Style helper for tabs
  const getTabStyle = (isActive) => ({
    padding: '10px 16px',
    border: 'none',
    borderBottomWidth: 2,
    borderBottomStyle: 'solid',
    borderBottomColor: isActive ? '#4060b0' : 'transparent',
    background: 'none',
    cursor: 'pointer',
    fontWeight: isActive ? 'bold' : 'normal',
    color: isActive ? '#4060b0' : '#38495e',
    textDecoration: 'none',
    display: 'flex',
    alignItems: 'center',
    whiteSpace: 'nowrap',
    flexShrink: 0
  })

  return (
    <div style={styles.container}>
      {/* Left scroll indicator */}
      {canScrollLeft && <div style={styles.scrollIndicatorLeft} />}

      {/* Scrollable tabs container */}
      <div ref={scrollRef} style={styles.scrollContainer}>
        <button
          onClick={() => onTabChange('settings')}
          style={getTabStyle(activeTab === 'settings')}
          data-active={activeTab === 'settings'}
        >
          Settings
        </button>
        <button
          onClick={() => onTabChange('advanced')}
          style={getTabStyle(activeTab === 'advanced')}
          data-active={activeTab === 'advanced'}
        >
          Advanced
        </button>
        <button
          onClick={() => onTabChange('nodelets')}
          style={getTabStyle(activeTab === 'nodelets')}
          data-active={activeTab === 'nodelets'}
        >
          Nodelets
        </button>
        <button
          onClick={() => onTabChange('notifications')}
          style={getTabStyle(activeTab === 'notifications')}
          data-active={activeTab === 'notifications'}
        >
          Notifications
        </button>
        {showAdminTab && (
          <button
            onClick={() => onTabChange('admin')}
            style={getTabStyle(activeTab === 'admin')}
            data-active={activeTab === 'admin'}
          >
            Admin
          </button>
        )}

        {/* Spacer - only on desktop */}
        <div style={styles.spacer} />

        {/* Edit Profile tab */}
        {username && (
          <button
            onClick={() => onTabChange('profile')}
            style={getTabStyle(activeTab === 'profile')}
            data-active={activeTab === 'profile'}
          >
            Edit Profile
          </button>
        )}

        {/* View Profile link */}
        {username && (
          <a
            href={`/user/${encodeURIComponent(username)}`}
            style={{
              ...getTabStyle(false),
              marginLeft: '8px'
            }}
          >
            View Profile
          </a>
        )}
      </div>

      {/* Right scroll indicator */}
      {canScrollRight && <div style={styles.scrollIndicatorRight} />}
    </div>
  )
}

const styles = {
  container: {
    position: 'relative',
    marginBottom: '20px'
  },
  scrollContainer: {
    display: 'flex',
    gap: 0,
    alignItems: 'center',
    borderBottom: '1px solid #ddd',
    overflowX: 'auto',
    overflowY: 'hidden',
    WebkitOverflowScrolling: 'touch',
    scrollbarWidth: 'none',  // Firefox
    msOverflowStyle: 'none'  // IE/Edge
  },
  spacer: {
    flex: 1,
    minWidth: 0
  },
  scrollIndicatorLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 1, // Account for border
    width: 30,
    background: 'linear-gradient(to right, rgba(255,255,255,1) 0%, rgba(255,255,255,0) 100%)',
    pointerEvents: 'none',
    zIndex: 1
  },
  scrollIndicatorRight: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 1, // Account for border
    width: 30,
    background: 'linear-gradient(to left, rgba(255,255,255,1) 0%, rgba(255,255,255,0) 100%)',
    pointerEvents: 'none',
    zIndex: 1
  }
}

export default SettingsNavigation
