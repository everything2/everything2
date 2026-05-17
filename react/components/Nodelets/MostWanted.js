import React from 'react'
import NodeletContainer from '../NodeletContainer'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

const MostWanted = (props) => {
  if (!props.bounties || !Array.isArray(props.bounties) || props.bounties.length === 0) {
    return (
      <NodeletContainer
        id={props.id}
        title="Most Wanted"
        showNodelet={props.showNodelet}
        nodeletIsOpen={props.nodeletIsOpen}
      >
        <p className="most-wanted__empty">
          <em>No bounties available</em>
        </p>
      </NodeletContainer>
    )
  }

  return (
    <NodeletContainer
      id={props.id}
      title="Most Wanted"
      showNodelet={props.showNodelet}
      nodeletIsOpen={props.nodeletIsOpen}
    >
      <table className="mytable most-wanted__table">
        <thead>
          <tr>
            <th className="most-wanted__th">Requesting Sheriff</th>
            <th className="most-wanted__th">Outlaw Nodeshell</th>
            <th className="most-wanted__th">GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {props.bounties.map((bounty, index) => (
            <tr key={index}>
              <td className="most-wanted__td">
                <LinkNode
                  nodeId={bounty.requester_id}
                  title={bounty.requester_name}
                />
              </td>
              <td className="most-wanted__td">
                <ParseLinks text={bounty.outlaw_nodeshell} />
              </td>
              <td className="most-wanted__td">
                {bounty.reward || ''}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="most-wanted__footer">
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
