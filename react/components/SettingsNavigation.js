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

  // Helper to get tab class
  const getTabClass = (isActive, isLink = false) => {
    let cls = 'settings-nav__tab'
    if (isActive) cls += ' settings-nav__tab--active'
    if (isLink) cls += ' settings-nav__tab--link'
    return cls
  }

  return (
    <div className="settings-nav">
      {/* Left scroll indicator */}
      {canScrollLeft && <div className="settings-nav__scroll-left" />}

      {/* Scrollable tabs container */}
      <div ref={scrollRef} className="settings-nav__scroll-container">
        <button
          onClick={() => onTabChange('settings')}
          className={getTabClass(activeTab === 'settings')}
          data-active={activeTab === 'settings'}
        >
          Settings
        </button>
        <button
          onClick={() => onTabChange('advanced')}
          className={getTabClass(activeTab === 'advanced')}
          data-active={activeTab === 'advanced'}
        >
          Advanced
        </button>
        <button
          onClick={() => onTabChange('nodelets')}
          className={getTabClass(activeTab === 'nodelets')}
          data-active={activeTab === 'nodelets'}
        >
          Nodelets
        </button>
        <button
          onClick={() => onTabChange('notifications')}
          className={getTabClass(activeTab === 'notifications')}
          data-active={activeTab === 'notifications'}
        >
          Notifications
        </button>
        {showAdminTab && (
          <button
            onClick={() => onTabChange('admin')}
            className={getTabClass(activeTab === 'admin')}
            data-active={activeTab === 'admin'}
          >
            Admin
          </button>
        )}

        {/* Spacer - only on desktop */}
        <div className="settings-nav__spacer" />

        {/* Edit Profile tab */}
        {username && (
          <button
            onClick={() => onTabChange('profile')}
            className={getTabClass(activeTab === 'profile')}
            data-active={activeTab === 'profile'}
          >
            Edit Profile
          </button>
        )}

        {/* View Profile link */}
        {username && (
          <a
            href={`/user/${encodeURIComponent(username)}`}
            className={getTabClass(false, true)}
          >
            View Profile
          </a>
        )}
      </div>

      {/* Right scroll indicator */}
      {canScrollRight && <div className="settings-nav__scroll-right" />}
    </div>
  )
}

export default SettingsNavigation
