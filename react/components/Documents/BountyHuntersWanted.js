import React from 'react'
import LinkNode from '../LinkNode'
import ParseLinks from '../ParseLinks'

/**
 * BountyHuntersWanted - Displays the 5 most recently requested bounties
 * from Everything's Most Wanted.
 */
const BountyHuntersWanted = ({ data }) => {
  const { bounties, emw_node_id } = data

  return (
    <div style={styles.container}>
      <p>
        These are the five most recent bounties. If you fill one of these, please message the
        requesting noder to claim your prize. See{' '}
        <LinkNode id={emw_node_id} display="Everything's Most Wanted" /> for full details on
        conditions and rewards.
      </p>

      <table style={styles.table}>
        <thead>
          <tr>
            <th style={styles.th}>Requesting Sheriff</th>
            <th style={styles.th}>Outlaw Nodeshell</th>
            <th style={styles.th}>GP Reward (if any)</th>
          </tr>
        </thead>
        <tbody>
          {bounties.length > 0 ? (
            bounties.map((bounty, idx) => (
              <tr key={idx}>
                <td style={styles.td}>
                  <ParseLinks text={`[${bounty.requester}]`} />
                </td>
                <td style={styles.td}>
                  <ParseLinks text={bounty.outlaw} />
                </td>
                <td style={styles.td}>{bounty.reward}</td>
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={3} style={styles.td}>
                <em>No active bounties at this time.</em>
              </td>
            </tr>
          )}
        </tbody>
      </table>

      <p style={styles.footer}>
        (<LinkNode id={emw_node_id} display="see full list" />)
      </p>
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '8px',
    textAlign: 'left',
    border: '1px solid silver'
  },
  td: {
    padding: '8px',
    border: '1px solid silver'
  },
  footer: {
    textAlign: 'center',
    marginTop: '15px'
  }
}

export default BountyHuntersWanted
