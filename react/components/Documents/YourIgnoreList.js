import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Your Ignore List - Shows who you're ignoring and who's ignoring you
 *
 * Staff/chanops can check other users' ignore lists
 */
const YourIgnoreList = ({ data, user }) => {
  const { for_user, error, ignoring_messages_from = [], messages_ignored_by = [] } = data
  const isCurrentUser = for_user && user && for_user.node_id === user.node_id
  const canCheckOthers = user && (user.is_admin || user.is_chanop)

  return (
    <div className="document">
      {canCheckOthers && (
        <div style={{ marginBottom: '1em' }}>
          <p>Check on user: {/* TODO: Add username_selector component */}
            {error && <em style={{ color: '#8b0000', marginLeft: '0.5em' }}>{error}</em>}
          </p>
        </div>
      )}

      <p>
        {isCurrentUser ? 'You are ignoring' : (
          <>
            {for_user && <LinkNode nodeId={for_user.node_id} title={for_user.title} />} is ignoring
          </>
        )}:
      </p>

      {ignoring_messages_from.length === 0 ? (
        <em>no one</em>
      ) : (
        <ol>
          {ignoring_messages_from.map((n) => (
            <li key={n.node_id}>
              <LinkNode nodeId={n.node_id} title={n.title} />
            </li>
          ))}
        </ol>
      )}

      <p>
        {isCurrentUser ? 'You are being ignored by' : (
          <>
            {for_user && <LinkNode nodeId={for_user.node_id} title={for_user.title} />} is ignored by
          </>
        )}:
      </p>

      {messages_ignored_by.length === 0 ? (
        <em>no one</em>
      ) : (
        <ol>
          {messages_ignored_by.map((n) => (
            <li key={n.node_id}>
              <LinkNode nodeId={n.node_id} title={n.title} />
            </li>
          ))}
        </ol>
      )}

      <p>
        <small>
          You can ignore people more thoroughly at the <LinkNode title="Pit of Abomination" />
        </small>
      </p>
    </div>
  )
}

export default YourIgnoreList
