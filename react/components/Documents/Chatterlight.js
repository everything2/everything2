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

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      backgroundColor: '#f8f9f9',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'
    }}>
      {/* Header with optional Notifications, Messages, and New Writeups */}
      {hasAnyHeaderNodelet && (
        <div style={{
          borderBottom: '1px solid #d3d3d3',
          backgroundColor: '#fff',
          padding: '8px 12px'
        }}>
          <div style={{
            maxWidth: '1200px',
            margin: '0 auto',
            display: 'grid',
            gridTemplateColumns: hasNewWriteups ? '1fr 1fr 1fr' : (hasNotifications && hasMessages ? '1fr 1fr' : '1fr'),
            gap: '12px'
          }}>
            {hasNotifications && (
              <div>
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
              <div>
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
              <div>
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
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'row',
        gap: '12px',
        padding: '12px',
        overflow: 'hidden',
        flexWrap: 'wrap'
      }}>
        {/* Chatterbox - takes 2/3 width on desktop, full width on mobile */}
        <div style={{
          flex: '2 1 500px',
          minWidth: '300px',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden'
        }}>
          <Chatterbox
            e2={e2}
            user={user}
            showNodelet={true}
            nodeletIsOpen={true}
          />
        </div>

        {/* Other Users - takes 1/3 width on desktop, full width on mobile */}
        <div style={{
          flex: '1 1 300px',
          minWidth: '250px',
          maxWidth: '400px',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'auto'
        }}>
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
      <div style={{
        padding: '20px',
        backgroundColor: '#f8f9f9',
        borderTop: '1px solid #d3d3d3',
        textAlign: 'center'
      }}>
        <a
          href="/"
          style={{
            display: 'inline-block',
            padding: '12px 24px',
            backgroundColor: '#4060b0',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '4px',
            fontWeight: '500',
            transition: 'background-color 0.2s'
          }}
          onMouseOver={(e) => e.target.style.backgroundColor = '#38495e'}
          onMouseOut={(e) => e.target.style.backgroundColor = '#4060b0'}
        >
          Back to Full Site
        </a>
      </div>
    </div>
  )
}

export default Chatterlight
