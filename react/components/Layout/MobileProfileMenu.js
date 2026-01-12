import React, { useState, useRef, useEffect } from 'react'
import { FaUser, FaSignOutAlt, FaCog, FaUserCircle, FaStar, FaCaretUp, FaFire } from 'react-icons/fa'

/**
 * MobileProfileMenu - Dropdown menu for logged-in users on mobile
 *
 * Shows:
 * - Username
 * - Level and XP
 * - Votes/C!s left
 * - Divider
 * - Profile link
 * - Settings link
 * - Log Out link
 */
const MobileProfileMenu = ({ user }) => {
  const [isOpen, setIsOpen] = useState(false)
  const menuRef = useRef(null)

  // Close menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
      document.addEventListener('touchstart', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
      document.removeEventListener('touchstart', handleClickOutside)
    }
  }, [isOpen])

  // Close on escape key
  useEffect(() => {
    const handleEscape = (event) => {
      if (event.key === 'Escape') {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('keydown', handleEscape)
    }

    return () => {
      document.removeEventListener('keydown', handleEscape)
    }
  }, [isOpen])

  const handleLogout = () => {
    // E2 logout is handled by navigating to the logout URL
    window.location.href = '/?op=logout'
  }

  return (
    <div ref={menuRef} className="mobile-profile-container">
      {/* Avatar button */}
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="mobile-profile-avatar-btn"
        aria-expanded={isOpen}
        aria-haspopup="true"
        aria-label="User menu"
      >
        <FaUser />
      </button>

      {/* Dropdown menu */}
      {isOpen && (
        <div className="mobile-profile-dropdown">
          {/* User info section */}
          <div className="mobile-profile-info">
            <div className="mobile-profile-username">{user.title}</div>
            <div className="mobile-profile-stats-row">
              <span className="mobile-profile-stat-item">
                <FaStar className="mobile-profile-stat-icon" />
                Level {user.level}
              </span>
              <span className="mobile-profile-stat-dot">&middot;</span>
              <span className="mobile-profile-stat-item">
                {user.experience} XP
              </span>
            </div>
            <div className="mobile-profile-stats-row">
              <span className="mobile-profile-stat-item">
                <FaCaretUp className="mobile-profile-stat-icon" />
                {user.votesleft} vote{user.votesleft !== 1 ? 's' : ''}
              </span>
              <span className="mobile-profile-stat-dot">&middot;</span>
              <span className="mobile-profile-stat-item">
                <FaFire className="mobile-profile-stat-icon mobile-profile-stat-icon--cool" />
                {user.coolsleft} C!{user.coolsleft !== 1 ? 's' : ''}
              </span>
            </div>
          </div>

          {/* Divider */}
          <div className="mobile-profile-divider" />

          {/* Menu items */}
          <a
            href={`/user/${encodeURIComponent(user.title)}`}
            className="mobile-profile-menu-item"
            onClick={() => setIsOpen(false)}
          >
            <FaUserCircle className="mobile-profile-menu-icon" />
            Profile
          </a>

          <a
            href="/title/Settings"
            className="mobile-profile-menu-item"
            onClick={() => setIsOpen(false)}
          >
            <FaCog className="mobile-profile-menu-icon" />
            Settings
          </a>

          <button
            type="button"
            onClick={handleLogout}
            className="mobile-profile-menu-item mobile-profile-menu-item--button"
          >
            <FaSignOutAlt className="mobile-profile-menu-icon" />
            Log Out
          </button>
        </div>
      )}
    </div>
  )
}

export default MobileProfileMenu
