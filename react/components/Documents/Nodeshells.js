import React from 'react'
import LinkNode from '../LinkNode'
import { formatShortDate } from '../../utils/dateFormat'

const Nodeshells = ({ data }) => {
  const { nodeshells } = data

  return (
    <div className="nodeshells">
      <p>
        Nodeshells are e2nodes with no writeups - empty containers waiting for content.
        These nodeshells were created in the last week.
      </p>

      {nodeshells.length === 0 ? (
        <p className="nodeshells__empty">
          No recent nodeshells found.
        </p>
      ) : (
        <>
          <p><strong>{nodeshells.length} nodeshell{nodeshells.length !== 1 ? 's' : ''} found</strong></p>
          <ul className="nodeshells__list">
            {nodeshells.map(({ node_id, title, createtime }) => (
              <li key={node_id} className="nodeshells__item">
                <LinkNode node_id={node_id} title={title} type="e2node" />
                <div className="nodeshells__created">
                  Created: {formatShortDate(createtime) ?? '?'}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}

      <div className="nodeshells__tip">
        <p className="nodeshells__tip-text">
          <strong>Fill a nodeshell!</strong> Click on any title above to add a writeup and help expand Everything2's knowledge base.
        </p>
      </div>
    </div>
  )
}

export default Nodeshells
