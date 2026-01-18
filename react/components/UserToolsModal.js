import React, { useState } from 'react'
import Modal from 'react-modal'
import { FaUserCog, FaTimes, FaInfoCircle, FaGavel, FaLock, FaGift, FaBan } from 'react-icons/fa'
import LinkNode from './LinkNode'
import './UserToolsModal.css'

/**
 * UserToolsModal - Admin tools modal for user management
 *
 * Features:
 * - User Info: Shows admin-only data (IP, browser/user-agent, account status)
 * - Moderation: Links to borg, suspend, and other admin actions
 * - Account Lock: Admin-only severe action to lock/unlock accounts
 *
 * Triggered by a wrench/cog icon next to the message envelope on homenodes
 */

const UserToolsModal = ({ user, viewer, isOpen, onClose }) => {
  const [selectedTool, setSelectedTool] = useState('info')
  // Track lock status locally for immediate UI updates
  const [lockStatus, setLockStatus] = useState(!!user?.acctlock)

  // Only show for editors/chanops
  if (!(viewer?.is_editor || viewer?.is_chanop || viewer?.is_admin)) {
    return null
  }

  const tools = [
    { id: 'info', label: 'User Info', icon: FaInfoCircle },
    { id: 'moderation', label: 'Moderation', icon: FaGavel }
  ]

  // Add Bestow tab for editors and admins
  if (viewer?.is_editor || viewer?.is_admin) {
    tools.push({ id: 'bestow', label: 'Bestow', icon: FaGift })
  }

  // Add Account Lock tab for admins only
  if (viewer?.is_admin) {
    tools.push({ id: 'lock', label: 'Account Lock', icon: FaLock })
  }

  const handleClose = () => {
    setSelectedTool('info')
    onClose()
  }

  // Callback for when lock status changes - updates both panels
  const handleLockStatusChange = (newLockStatus) => {
    setLockStatus(newLockStatus)
  }

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={handleClose}
      className="user-tools-modal"
      overlayClassName="user-tools-modal-overlay"
      contentLabel="User Tools"
    >
      <div className="user-tools-container">
        {/* Header */}
        <div className="user-tools-header">
          <h2><FaUserCog /> User Tools</h2>
          <button onClick={handleClose} className="close-button" aria-label="Close">
            <FaTimes />
          </button>
        </div>

        {/* Current User Info */}
        <div className="user-tools-user-info">
          <strong>User:</strong> {user.title}
        </div>

        {/* Content Area */}
        <div className="user-tools-content">
          {/* Left Menu */}
          <nav className="user-tools-menu">
            {tools.map(tool => (
              <button
                key={tool.id}
                className={`menu-item ${selectedTool === tool.id ? 'active' : ''} ${tool.danger ? 'danger' : ''}`}
                onClick={() => setSelectedTool(tool.id)}
              >
                <tool.icon /> {tool.label}
              </button>
            ))}
          </nav>

          {/* Right Panel */}
          <div className="user-tools-panel">
            {selectedTool === 'info' && (
              <UserInfoPanel user={user} viewer={viewer} lockStatus={lockStatus} />
            )}

            {selectedTool === 'moderation' && (
              <ModerationPanel user={user} viewer={viewer} />
            )}

            {selectedTool === 'bestow' && (
              <BestowPanel user={user} viewer={viewer} />
            )}

            {selectedTool === 'lock' && (
              <AccountLockPanel user={user} viewer={viewer} lockStatus={lockStatus} onLockStatusChange={handleLockStatusChange} />
            )}
          </div>
        </div>
      </div>
    </Modal>
  )
}

/**
 * UserInfoPanel - Display admin-only user information
 */
const UserInfoPanel = ({ user, viewer, lockStatus }) => {
  return (
    <div className="user-info-panel">
      <h3>User Information</h3>

      <dl className="info-list">
        <dt>User ID</dt>
        <dd>{user.node_id}</dd>

        {user.lastip && (
          <>
            <dt>Last IP Address</dt>
            <dd className="ip-address">
              {user.lastip}
              {user.ip_blacklisted === 1 && (
                <span className="status-blacklisted" style={{ marginLeft: '8px', color: '#d9534f' }}>
                  <FaBan /> Blacklisted
                </span>
              )}
            </dd>

            <dt>IP Lookup Tools</dt>
            <dd className="ip-lookup-tools">
              <a href={`https://whois.domaintools.com/${user.lastip}`} target="_blank" rel="noopener noreferrer">whois</a>
              {' - '}
              <a href={`https://www.google.com/search?q=%22${user.lastip}%22`} target="_blank" rel="noopener noreferrer">Google</a>
              {' - '}
              <a href={`https://www.projecthoneypot.org/ip_${user.lastip}`} target="_blank" rel="noopener noreferrer">Project Honeypot</a>
              {' - '}
              <a href={`https://www.stopforumspam.com/ipcheck/${user.lastip}`} target="_blank" rel="noopener noreferrer">Stop Forum Spam</a>
              {' - '}
              <a href={`https://www.botscout.com/ipcheck.htm?ip=${user.lastip}`} target="_blank" rel="noopener noreferrer">BotScout</a>
            </dd>
          </>
        )}

        {user.browser && (
          <>
            <dt>Last Browser/User-Agent</dt>
            <dd><code className="user-agent">{user.browser}</code></dd>
          </>
        )}

        <dt>Account Status</dt>
        <dd>
          {lockStatus ? (
            <span className="status-locked">
              <FaBan /> Locked
              {user.acctlock?.title && (
                <> by <LinkNode nodeId={user.acctlock.node_id} title={user.acctlock.title} /></>
              )}
            </span>
          ) : (
            <span className="status-active">Active</span>
          )}
        </dd>

        {user.infected === 1 && viewer.is_editor === 1 && (
          <>
            <dt>Infection Status</dt>
            <dd><span className="status-infected">Infected (potential bot)</span></dd>
          </>
        )}

        <dt>Experience</dt>
        <dd>{user.experience} XP</dd>

        <dt>Level</dt>
        <dd>{user.leveltitle} ({user.level})</dd>

        <dt>Writeups</dt>
        <dd>{user.numwriteups}</dd>

        {viewer.is_admin === 1 && user.GP !== undefined && (
          <>
            <dt>GP</dt>
            <dd>{user.GP}</dd>
          </>
        )}

        {user.email && viewer.is_admin === 1 && (
          <>
            <dt>Email</dt>
            <dd>{user.email}</dd>
          </>
        )}
      </dl>
    </div>
  )
}

/**
 * ModerationPanel - Moderation actions for this user
 */
const ModerationPanel = ({ user, viewer }) => {
  return (
    <div className="moderation-panel">
      <h3>Moderation Actions</h3>

      <div className="action-list">
        {/* Borg */}
        {(viewer.is_editor || viewer.is_chanop) && (
          <div className="action-item">
            <h4>Borg User</h4>
            <p>Temporarily silence this user in the chatterbox.</p>
            <LinkNode
              type="superdoc"
              title="e2 bouncer"
              params={{ borguser: user.title }}
              className="action-button"
            >
              Borg {user.title}
            </LinkNode>
          </div>
        )}

        {/* Suspend */}
        {viewer.is_editor === 1 && (
          <div className="action-item">
            <h4>Suspend Account</h4>
            <p>View suspension history or apply a new suspension.</p>
            <LinkNode
              type="superdoc"
              title="Suspension Info"
              params={{ suspendee: user.title }}
              className="action-button"
            >
              Suspension Info
            </LinkNode>
          </div>
        )}

        {/* IP Hunter - admin only */}
        {viewer.is_admin === 1 && (
          <div className="action-item">
            <h4>IP Hunter</h4>
            <p>Search for other accounts using the same IP address as this user.</p>
            <LinkNode
              type="restricted_superdoc"
              title="IP Hunter"
              params={{ hunt_name: user.title }}
              className="action-button"
            >
              Hunt IPs for {user.title}
            </LinkNode>
          </div>
        )}

        {/* IP Blacklist - admin only */}
        {viewer.is_admin === 1 && user.lastip && (
          <div className="action-item">
            <h4>IP Blacklist</h4>
            <p>Add this user's IP address ({user.lastip}) to the blacklist.</p>
            <LinkNode
              type="restricted_superdoc"
              title="IP Blacklist"
              params={{ bad_ip: user.lastip }}
              className="action-button danger"
            >
              Blacklist {user.lastip}
            </LinkNode>
          </div>
        )}

      </div>
    </div>
  )
}

/**
 * BestowPanel - Links to admin bestow tools with user pre-filled
 */
const BestowPanel = ({ user, viewer }) => {
  const isAdmin = viewer?.is_admin === 1
  const isEditor = viewer?.is_editor === 1

  // Define bestow tools with their access levels
  const bestowTools = [
    {
      id: 'superbless',
      title: 'Superbless',
      description: 'Grant GP to this user. Positive values give GP, negative values remove GP.',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'Superbless',
      available: isEditor || isAdmin
    },
    {
      id: 'websterbless',
      title: 'Websterbless',
      description: 'Thank this user for suggesting corrections to Webster 1913.',
      nodeType: 'oppressor_superdoc',
      nodeTitle: 'Websterbless',
      available: isEditor || isAdmin
    },
    {
      id: 'bestow_cools',
      title: 'Bestow Cools',
      description: 'Grant C! (cools) to this user for highlighting excellent writeups.',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'Bestow Cools',
      available: isAdmin
    },
    {
      id: 'bestow_easter_eggs',
      title: 'Bestow Easter Eggs',
      description: 'Grant easter eggs to this user.',
      nodeType: 'superdoc',
      nodeTitle: 'Bestow Easter Eggs',
      available: isAdmin
    },
    {
      id: 'giant_teddy',
      title: 'Giant Teddy Bear Hug',
      description: 'Publicly hug this user with the Giant Teddy Bear (+2 GP, +1 karma).',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'Giant Teddy Bear Suit',
      available: isAdmin
    },
    {
      id: 'fiery_teddy',
      title: 'Fiery Teddy Bear Curse',
      description: 'Publicly curse this user with the Fiery Teddy Bear (-1 GP, -1 karma).',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'Fiery Teddy Bear Suit',
      available: isAdmin,
      danger: true
    },
    {
      id: 'enrichify',
      title: 'Enrichify',
      description: 'Admin GP tool - grant or remove GP from this user.',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'Enrichify',
      available: isAdmin
    },
    {
      id: 'xp_superbless',
      title: 'XP Superbless (Archived)',
      description: 'Legacy XP tool - use sparingly for extraordinary circumstances only.',
      nodeType: 'restricted_superdoc',
      nodeTitle: 'XP Superbless',
      available: isAdmin,
      archived: true
    }
  ]

  // Filter to only show tools the viewer has access to
  const availableTools = bestowTools.filter(tool => tool.available)

  return (
    <div className="bestow-panel">
      <h3>Bestow Resources</h3>
      <p className="panel-description">
        Grant GP, cools, or other resources to <strong>{user.title}</strong>.
      </p>

      <div className="bestow-list">
        {availableTools.map(tool => (
          <div
            key={tool.id}
            className={`bestow-item ${tool.danger ? 'danger' : ''} ${tool.archived ? 'archived' : ''}`}
          >
            <div className="bestow-info">
              <h4>{tool.title}</h4>
              <p>{tool.description}</p>
            </div>
            <LinkNode
              type={tool.nodeType}
              title={tool.nodeTitle}
              params={{ prefill_username: user.title }}
              className={`action-button ${tool.danger ? 'danger' : ''}`}
            >
              Open
            </LinkNode>
          </div>
        ))}
      </div>

      {isAdmin && (
        <div className="bestow-note">
          <strong>Note:</strong> All bestow actions are logged. Use these tools responsibly.
        </div>
      )}
    </div>
  )
}

/**
 * AccountLockPanel - Dedicated panel for account lock/unlock (admin only)
 */
const AccountLockPanel = ({ user, viewer, lockStatus, onLockStatusChange }) => {
  const [lockLoading, setLockLoading] = useState(false)
  const [lockError, setLockError] = useState(null)
  const [lockSuccess, setLockSuccess] = useState(null)

  const handleLockToggle = async () => {
    setLockLoading(true)
    setLockError(null)
    setLockSuccess(null)

    const action = lockStatus ? 'unlock' : 'lock'

    try {
      const response = await fetch(`/api/admin/user/${user.node_id}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      })

      const data = await response.json()

      if (data.success) {
        const newLockStatus = !lockStatus
        onLockStatusChange(newLockStatus)
        setLockSuccess(data.message)
      } else {
        setLockError(data.message || data.error || 'Unknown error')
      }
    } catch (err) {
      setLockError('Failed to ' + action + ' account: ' + err.message)
    } finally {
      setLockLoading(false)
    }
  }

  return (
    <div className="account-lock-panel">
      <h3>Account Lock</h3>
      <p className="panel-description">
        Locking an account is a severe action. It prevents the user from logging in.
      </p>

      <div className={`lock-action-box ${lockStatus ? 'locked' : 'unlocked'}`}>
        {lockStatus ? (
          <div className="lock-status-warning">
            <FaLock className="lock-icon" />
            <strong>This account is currently LOCKED</strong>
            <p>The user cannot log in. Unlock to restore access.</p>
          </div>
        ) : (
          <div className="lock-status-info">
            <FaLock className="lock-icon unlocked" />
            <strong>This account is active</strong>
            <p>Lock this account to prevent the user from logging in.</p>
          </div>
        )}

        {lockError && (
          <p className="action-error">{lockError}</p>
        )}
        {lockSuccess && (
          <p className="action-success">{lockSuccess}</p>
        )}

        <button
          onClick={handleLockToggle}
          disabled={lockLoading}
          className={`lock-action-button ${lockStatus ? 'unlock-button' : 'lock-button'}`}
        >
          {lockLoading
            ? (lockStatus ? 'Unlocking...' : 'Locking...')
            : (lockStatus ? 'Unlock Account' : 'Lock Account')
          }
        </button>
      </div>

      {/* Smite Spammer - link to The Old Hooked Pole */}
      <div className="smite-spammer-section">
        <h4>Smite Spammer</h4>
        <p>Use this to remove all writeups and nuke the account of a confirmed spammer.</p>
        <LinkNode
          type="restricted_superdoc"
          title="The Old Hooked Pole"
          params={{ prefill: user.title }}
          className="action-button danger"
        >
          Smite {user.title}
        </LinkNode>
      </div>
    </div>
  )
}

export default UserToolsModal
