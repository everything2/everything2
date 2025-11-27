import React from 'react'
import LinkNode from '../LinkNode'

const Nodeshells = ({ data }) => {
  const { nodeshells } = data

  return (
    <div className="nodeshells">
      <h2>Nodeshells</h2>
      <p>
        Nodeshells are e2nodes with no writeups - empty containers waiting for content.
        These nodeshells were created in the last week.
      </p>

      {nodeshells.length === 0 ? (
        <p style={{ fontStyle: 'italic', color: '#666' }}>
          No recent nodeshells found.
        </p>
      ) : (
        <>
          <p><strong>{nodeshells.length} nodeshell{nodeshells.length !== 1 ? 's' : ''} found</strong></p>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            {nodeshells.map(({ node_id, title, createtime }) => (
              <li key={node_id} style={{ marginBottom: '10px', padding: '8px', backgroundColor: '#f9f9f9', borderLeft: '3px solid #ddd' }}>
                <LinkNode node_id={node_id} title={title} type="e2node" />
                <div style={{ fontSize: '0.85em', color: '#888', marginTop: '4px' }}>
                  Created: {new Date(createtime).toLocaleDateString()}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}

      <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#fff3cd', borderRadius: '4px', borderLeft: '4px solid #ffc107' }}>
        <p style={{ margin: 0, fontSize: '0.9em' }}>
          <strong>Fill a nodeshell!</strong> Click on any title above to add a writeup and help expand Everything2's knowledge base.
        </p>
      </div>
    </div>
  )
}

export default Nodeshells
