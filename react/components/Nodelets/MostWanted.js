import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

const MostWanted = (props) => {
  if (!props.bounties || !Array.isArray(props.bounties) || props.bounties.length === 0) {
    return (
      <NodeletContainer
        title="Most Wanted"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p style={{ padding: '8px', color: '#666', fontSize: '12px' }}>
          <em>No bounties available</em>
        </p>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      title="Most Wanted"
      showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
    >
      <table className="mytable" style={{ width: '100%', fontSize: '12px', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={{ textAlign: 'left', padding: '4px' }}>Requesting Sheriff</th>
            <th style={{ textAlign: 'left', padding: '4px' }}>Outlaw Nodeshell</th>
            <th style={{ textAlign: 'left', padding: '4px' }}>GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {props.bounties.map((bounty, index) => (
            <tr key={index}>
              <td style={{ padding: '4px' }}>
                <LinkNode
                  nodeId={bounty.requester_id}
                  title={bounty.requester_name}
                />
              </td>
              <td style={{ padding: '4px' }}>
                <ParseLinks text={bounty.outlaw_nodeshell} />
              </td>
              <td style={{ padding: '4px' }}>
                {bounty.reward || ''}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <p style={{ fontSize: '11px', marginTop: '8px', padding: '0 4px' }}>
        <small>
          Fill these nodes and get rewards! More details at{' '}
          <LinkNode title="Everything's Most Wanted" />
          .
        </small>
      </p>
    </NodeletContainer>
  )
}

export default MostWanted
