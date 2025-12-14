import React from 'react'
import WriteupDisplay from './WriteupDisplay'
import LinkNode from './LinkNode'

/**
 * E2NodeDisplay - Renders an e2node with all its writeups
 *
 * Displays:
 * - E2node title
 * - All writeups under this e2node
 * - Softlinks
 * - Created by info
 *
 * Usage:
 *   <E2NodeDisplay e2node={e2nodeData} user={userData} />
 */
const E2NodeDisplay = ({ e2node, user }) => {
  if (!e2node) return null

  const {
    title,
    group,           // Array of writeups
    softlinks,
    createdby
  } = e2node

  return (
    <div className="e2node-display">
      {/* E2node header */}
      <div className="e2node-header">
        <h1 className="e2node-title" style={{ fontSize: 'inherit' }}>{title}</h1>

        {createdby && (
          <div className="e2node-meta">
            Created by <LinkNode type="user" title={createdby.title} />
          </div>
        )}
      </div>

      {/* Writeups */}
      <div className="e2node-writeups">
        {group && group.length > 0 ? (
          group.map((writeup) => (
            <WriteupDisplay
              key={writeup.node_id}
              writeup={writeup}
              user={user}
            />
          ))
        ) : (
          <p>No writeups yet.</p>
        )}
      </div>

      {/* Softlinks */}
      {softlinks && softlinks.length > 0 && (
        <div className="softlinks">
          <h3>Softlinks:</h3>
          <ul>
            {softlinks.map((link) => (
              <li key={link.node_id}>
                <LinkNode
                  nodeId={link.node_id}
                  title={link.title}
                  type={link.type || 'e2node'}
                />
                {link.hits && <span className="hits"> ({link.hits})</span>}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}

export default E2NodeDisplay
