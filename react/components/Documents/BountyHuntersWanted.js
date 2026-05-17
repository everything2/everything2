import React from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * BountyHuntersWanted - Displays the 5 most recently requested bounties
 * from Everything's Most Wanted.
 * Styles in CSS: .bounty-hunters-wanted__*
 */
const BountyHuntersWanted = ({ data }) => {
  const { bounties, emw_node_id } = data

  return (
    <div className="bounty-hunters-wanted">
      <p>
        These are the five most recent bounties. If you fill one of these, please message the
        requesting noder to claim your prize. See{' '}
        <LinkNode id={emw_node_id} display="Everything's Most Wanted" /> for full details on
        conditions and rewards.
      </p>

      <table className="bounty-hunters-wanted__table">
        <thead>
          <tr>
            <th className="bounty-hunters-wanted__th">Requesting Sheriff</th>
            <th className="bounty-hunters-wanted__th">Outlaw Nodeshell</th>
            <th className="bounty-hunters-wanted__th">GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {bounties.length > 0 ? (
            bounties.map((bounty, idx) => (
              <tr key={idx}>
                <td className="bounty-hunters-wanted__td">
                  <ParseLinks text={`[${bounty.requester}]`} />
                </td>
                <td className="bounty-hunters-wanted__td">
                  <ParseLinks text={bounty.outlaw} />
                </td>
                <td className="bounty-hunters-wanted__td">{bounty.reward}</td>
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={3} className="bounty-hunters-wanted__td">
                <em>No active bounties at this time.</em>
              </td>
            </tr>
          )}
        </tbody>
      </table>

      <p className="bounty-hunters-wanted__footer">
        (<LinkNode id={emw_node_id} display="see full list" />)
      </p>
    </div>
  )
}

export default BountyHuntersWanted
