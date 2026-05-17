import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Your Filled Nodeshells - Shows user's nodeshells that have been filled by others
 * Styles in CSS: .your-filled-nodeshells__*
 *
 * Displays nodeshells (e2nodes) created by the user that:
 * 1. Have been filled by someone else (have writeups)
 * 2. User doesn't have their own writeup in them
 */
const YourFilledNodeshells = ({ data }) => {
  const { nodeshells = [], count = 0 } = data

  return (
    <div className="your-filled-nodeshells">
      <p>(Be sure to check out <a href="/title/Your+nodeshells" className="your-filled-nodeshells__link">Your nodeshells</a>, too.)</p>

      <p>
        <strong>{count}</strong> nodeshell{count !== 1 ? 's' : ''} created by you which {count !== 1 ? 'have' : 'has'} been filled by someone else:
      </p>

      {nodeshells.length === 0 ? (
        <p className="your-filled-nodeshells__empty-state">No filled nodeshells found.</p>
      ) : (
        <ul className="your-filled-nodeshells__list">
          {nodeshells.map((n) => (
            <li key={n.node_id} className="your-filled-nodeshells__list-item">
              <LinkNode nodeId={n.node_id} title={n.title} />
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default YourFilledNodeshells
