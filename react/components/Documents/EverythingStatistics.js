import React from 'react'
import LinkNode from '../LinkNode'

/**
 * EverythingStatistics - Site-wide statistics display
 *
 * Shows total counts for nodes, writeups, users, and links
 */
const EverythingStatistics = ({ data }) => {
  const {
    total_nodes,
    total_writeups,
    total_users,
    total_links,
    finger_node_id,
    news_node_id
  } = data

  const formatNumber = (num) => {
    return Number(num).toLocaleString()
  }

  return (
    <div style={styles.container}>
      <p>Total Number of Nodes: {formatNumber(total_nodes)}</p>
      <p>Total Number of Writeups: {formatNumber(total_writeups)}</p>
      <p>Total Number of Users: {formatNumber(total_users)}</p>
      <p>Total Number of Links: {formatNumber(total_links)}</p>

      <p>
        You may also find the{' '}
        {finger_node_id ? (
          <LinkNode nodeId={finger_node_id} title="Everything Finger" />
        ) : (
          'Everything Finger'
        )}{' '}
        interesting if you are looking to pull something useful out of all these nodes. Useful? Ha.
      </p>

      {news_node_id && (
        <p>
          <LinkNode nodeId={news_node_id} title="news for noders. stuff that matters." />
        </p>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '20px',
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  }
}

export default EverythingStatistics
