import React, { useState } from 'react'
import { FaPen, FaCompass, FaComments, FaEnvelope, FaBell, FaUser } from 'react-icons/fa'
import DiscoverMenu from './DiscoverMenu'
import MobileInboxModal from './MobileInboxModal'
import MobileChatModal from './MobileChatModal'
import MobileNotificationsModal from './MobileNotificationsModal'

/**
 * Individual navigation item for the bottom nav bar
 */
const NavItem = ({ icon: Icon, label, href, onClick, badge, active }) => {
  const content = (
    <>
      <div className="mobile-nav-icon-wrapper">
        <Icon className="mobile-nav-icon" />
        {badge > 0 && <span className="mobile-nav-badge">{badge > 99 ? '99+' : badge}</span>}
      </div>
      <span className="mobile-nav-label">{label}</span>
    </>
  )

  const itemClass = `mobile-nav-item${active ? ' mobile-nav-item--active' : ''}`

  if (href) {
    return (
      <a href={href} className={itemClass}>
        {content}
      </a>
    )
  }

  return (
    <button type="button" onClick={onClick} className={itemClass}>
      {content}
    </button>
  )
}

/**
 * MobileBottomNav - Bottom navigation bar for mobile devices
 *
 * Displays different items based on login status:
 * - Guests: Discover, Sign In (2 items) - Chat requires login
 * - Logged-in: Write, Discover, Chat, Inbox, Notifications (5 items)
 */
const MobileBottomNav = ({
  user,
  unreadMessages: initialUnreadMessages = 0,
  onShowAuth,
  initialMessages = [],
  chatterMessages = [],
  chatterCount: initialChatterCount = 0,
  otherUsersData = null,
  otherUsersCount = 0,
  currentRoom = 0,
  publicChatterOff = false,
  isBorged = false,
  notificationsData = null,
  notificationsCount: initialNotificationsCount = 0
}) => {
  const [showDiscover, setShowDiscover] = useState(false)
  const [showInbox, setShowInbox] = useState(false)
  const [showChat, setShowChat] = useState(false)
  const [showNotifications, setShowNotifications] = useState(false)
  const [chatterCount, setChatterCount] = useState(initialChatterCount)
  const [notificationsCount, setNotificationsCount] = useState(initialNotificationsCount)
  const [unreadMessages, setUnreadMessages] = useState(initialUnreadMessages)
  const isGuest = user?.guest

  // Callback to update chatter count when modal fetches new messages
  const handleChatterUpdate = (count) => {
    setChatterCount(count)
  }

  // Callback to update notifications count when modal fetches new data
  const handleNotificationsUpdate = (count) => {
    setNotificationsCount(count)
  }

  // Callback to update unread messages count when inbox modal loads/modifies messages
  const handleMessagesUpdate = (count) => {
    setUnreadMessages(count)
  }

  return (
    <>
      <nav className="mobile-bottom-nav">
        {!isGuest && (
          <NavItem
            icon={FaPen}
            label="Write"
            href="/title/Drafts"
          />
        )}
        <NavItem
          icon={FaCompass}
          label="Discover"
          onClick={() => setShowDiscover(true)}
        />
        {!isGuest && (
          <NavItem
            icon={FaComments}
            label="Chat"
            onClick={() => setShowChat(true)}
            badge={chatterCount}
          />
        )}
        {!isGuest ? (
          <>
            <NavItem
              icon={FaEnvelope}
              label="Inbox"
              onClick={() => setShowInbox(true)}
              badge={unreadMessages}
            />
            <NavItem
              icon={FaBell}
              label="Notify"
              onClick={() => setShowNotifications(true)}
              badge={notificationsCount}
            />
          </>
        ) : (
          <NavItem
            icon={FaUser}
            label="Sign In"
            onClick={onShowAuth}
          />
        )}
      </nav>

      {showDiscover && (
        <DiscoverMenu onClose={() => setShowDiscover(false)} />
      )}

      {showInbox && (
        <MobileInboxModal
          isOpen={showInbox}
          onClose={() => setShowInbox(false)}
          initialMessages={initialMessages}
          onMessagesUpdate={handleMessagesUpdate}
        />
      )}

      {showChat && (
        <MobileChatModal
          isOpen={showChat}
          onClose={() => setShowChat(false)}
          user={user}
          initialChatter={chatterMessages}
          otherUsersData={otherUsersData}
          currentRoom={currentRoom}
          isGuest={isGuest}
          isBorged={isBorged}
          publicChatterOff={publicChatterOff}
          onChatterUpdate={handleChatterUpdate}
        />
      )}

      {showNotifications && (
        <MobileNotificationsModal
          isOpen={showNotifications}
          onClose={() => setShowNotifications(false)}
          initialNotifications={notificationsData}
          onNotificationsUpdate={handleNotificationsUpdate}
        />
      )}
    </>
  )
}

export default MobileBottomNav
