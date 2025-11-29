import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Your Nodeshells - Shows nodeshells created by a user
 *
 * Nodeshells are e2nodes with no writeups
 */
const YourNodeshells = ({ data, user }) => {
  const { for_user, error, nodeshells = [] } = data
  const isCurrentUser = for_user && user && for_user.node_id === user.node_id

  return (
    <div className="document">
      {error && (
        <p style={{ color: '#8b0000', fontStyle: 'italic' }}>{error}</p>
      )}

      <p>
        {isCurrentUser ? 'Your' : (
          <>
            {for_user && <LinkNode nodeId={for_user.node_id} title={for_user.title} />}'s
          </>
        )} nodeshells:
      </p>

      {nodeshells.length === 0 ? (
        <p><em>No nodeshells found</em></p>
      ) : (
        <ol>
          {nodeshells.map((n) => (
            <li key={n.node_id}>
              <LinkNode nodeId={n.node_id} title={n.title} />
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

export default YourNodeshells
