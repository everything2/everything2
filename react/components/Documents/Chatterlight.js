import React from 'react'
import Chatterbox from '../Nodelets/Chatterbox'
import OtherUsers from '../Nodelets/OtherUsers'
import Notifications from '../Nodelets/Notifications'
import Messages from '../Nodelets/Messages'
import NewWriteups from '../Nodelets/NewWriteups'

/**
 * Chatterlight - Fullpage chatterbox view
 *
 * A focused chat interface with no Mason header/sidebar/footer
 * Shows only the nodelets we explicitly render:
 * - Chatterbox (main area)
 * - Other Users (sidebar)
 * - Notifications (header, if user has it)
 * - Messages (header)
 * - New Writeups (header, chatterlighter only)
 *
 * This is a fullpage layout used by:
 * - chatterlight (fullpage) - Notifications + Messages
 * - chatterlight classic (fullpage) - Messages only
 * - chatterlighter (superdoc/fullpage) - Notifications + New Writeups + Messages
 */
const Chatterlight = ({ data, user, e2 }) => {
  const { pagenodelets = [] } = data

  // Nodelet IDs (from database)
  const NOTIFICATIONS_ID = 1930708
  const MESSAGES_ID = 2044453
  const NEW_WRITEUPS_ID = 263

  // Convert pagenodelets to numbers (they come as strings from Perl)
  const nodeletIds = pagenodelets.map(id => parseInt(id, 10))

  // Determine which header nodelets to show based on pagenodelets array
  const hasNotifications = nodeletIds.includes(NOTIFICATIONS_ID)
  const hasMessages = nodeletIds.includes(MESSAGES_ID)
  const hasNewWriteups = nodeletIds.includes(NEW_WRITEUPS_ID)
  const hasAnyHeaderNodelet = hasNotifications || hasMessages || hasNewWriteups

  // Ref for Messages scroll container
  const messagesContainerRef = React.useRef(null)

  // Auto-scroll Messages to bottom when messages change
  React.useEffect(() => {
    if (messagesContainerRef.current && e2?.messagesData?.length > 0) {
      messagesContainerRef.current.scrollTop = messagesContainerRef.current.scrollHeight
    }
  }, [e2?.messagesData])

  // Determine grid class based on number of header nodelets
  const getGridClass = () => {
    if (hasNewWriteups) return 'chatterlight__header-grid chatterlight__header-grid--three-col'
    if (hasNotifications && hasMessages) return 'chatterlight__header-grid chatterlight__header-grid--two-col'
    return 'chatterlight__header-grid chatterlight__header-grid--one-col'
  }

  return (
    <div className="chatterlight">
      {/* Header with optional Notifications, Messages, and New Writeups */}
      {hasAnyHeaderNodelet && (
        <div className="chatterlight__header">
          <div className={getGridClass()}>
            {hasNotifications && (
              <div className="chatterlight__header-nodelet">
                <Notifications
                  e2={e2}
                  user={user}
                  showNodelet={true}
                  nodeletIsOpen={true}
                  notificationsData={e2?.notificationsData}
                />
              </div>
            )}
            {hasNewWriteups && (
              <div className="chatterlight__header-nodelet">
                <NewWriteups
                  e2={e2}
                  user={user}
                  showNodelet={true}
                  nodeletIsOpen={true}
                  limit={5}
                  noJunk={true}
                  newWriteups={e2?.newWriteups}
                />
              </div>
            )}
            {hasMessages && (
              <div
                ref={messagesContainerRef}
                className="chatterlight__header-nodelet"
              >
                <Messages
                  e2={e2}
                  user={user}
                  showNodelet={true}
                  nodeletIsOpen={true}
                  initialMessages={e2?.messagesData}
                />
              </div>
            )}
          </div>
        </div>
      )}

      {/* Main chat area - Chatterbox + Other Users side by side */}
      <div className="chatterlight__main">
        {/* Chatterbox - takes 2/3 width on desktop, full width on mobile */}
        <div className="chatterlight__chat-area">
          <Chatterbox
            e2={e2}
            user={user}
            showNodelet={true}
            nodeletIsOpen={true}
          />
        </div>

        {/* Other Users - takes 1/3 width on desktop, full width on mobile */}
        <div className="chatterlight__users-area">
          <OtherUsers
            e2={e2}
            user={user}
            showNodelet={true}
            nodeletIsOpen={true}
            otherUsersData={e2?.otherUsersData}
          />
        </div>
      </div>

      {/* Footer navigation */}
      <div className="chatterlight__footer">
        <a href="/" className="chatterlight__back-link">
          Back to Full Site
        </a>
      </div>
    </div>
  )
}

export default Chatterlight
