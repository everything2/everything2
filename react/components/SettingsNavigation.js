import React from 'react'

/**
 * SettingsNavigation - Navigation tabs for the unified Settings page
 *
 * Provides tab navigation between Settings, Advanced, Nodelets, Admin (editors),
 * Edit Profile, and View Profile.
 *
 * Props:
 * - activeTab: Current active tab ('settings', 'advanced', 'nodelets', 'admin', 'profile')
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
  // Style helper for tabs
  const getTabStyle = (tabName, isActive) => ({
    padding: '10px 16px',
    border: 'none',
    borderBottom: isActive ? '2px solid #4060b0' : '2px solid transparent',
    background: 'none',
    cursor: 'pointer',
    fontWeight: isActive ? 'bold' : 'normal',
    color: isActive ? '#4060b0' : '#38495e',
    textDecoration: 'none',
    display: 'flex',
    alignItems: 'center'
  })

  return (
    <div style={{
      borderBottom: '1px solid #ddd',
      marginBottom: '20px',
      display: 'flex',
      gap: '0',
      alignItems: 'center'
    }}>
      <button
        onClick={() => onTabChange('settings')}
        style={getTabStyle('settings', activeTab === 'settings')}
      >
        Settings
      </button>
      <button
        onClick={() => onTabChange('advanced')}
        style={getTabStyle('advanced', activeTab === 'advanced')}
      >
        Advanced
      </button>
      <button
        onClick={() => onTabChange('nodelets')}
        style={getTabStyle('nodelets', activeTab === 'nodelets')}
      >
        Nodelets
      </button>
      {showAdminTab && (
        <button
          onClick={() => onTabChange('admin')}
          style={getTabStyle('admin', activeTab === 'admin')}
        >
          Admin
        </button>
      )}

      {/* Spacer */}
      <div style={{ flex: 1 }} />

      {/* Edit Profile tab */}
      {username && (
        <button
          onClick={() => onTabChange('profile')}
          style={getTabStyle('profile', activeTab === 'profile')}
        >
          Edit Profile
        </button>
      )}

      {/* View Profile link */}
      {username && (
        <a
          href={`/user/${encodeURIComponent(username)}`}
          style={{
            ...getTabStyle('view', false),
            marginLeft: '8px'
          }}
        >
          View Profile
        </a>
      )}
    </div>
  )
}

export default SettingsNavigation
