import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything's Richest Noders - Display GP wealth distribution
 * Shows top 1500 richest, 10 poorest, and top 10 with statistics
 */
const EverythingSRichestNoders = ({ data }) => {
  const {
    total_gp = 0,
    richest_all = [],
    poorest = [],
    richest_top = [],
    richest_top_gp = 0,
    top_percentage = 0,
    limit_all = 1500,
    limit_top = 10
  } = data

  return (
    <div style={styles.container}>
      {/* Top 1500 Richest Users */}
      <h3 style={styles.heading}>{limit_all} Richest Noders</h3>
      <ol style={styles.list}>
        {richest_all.map((user, index) => (
          <li key={user.user_id} style={styles.listItem}>
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr style={styles.divider} />

      {/* 10 Poorest Users (excluding 0 GP) */}
      <h3 style={styles.heading}>{limit_top} Poorest Noders (ignore 0GP)</h3>
      <ol style={styles.list}>
        {poorest.map((user, index) => (
          <li key={user.user_id} style={styles.listItem}>
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr style={styles.divider} />

      {/* Top 10 Richest Users */}
      <h3 style={styles.heading}>{limit_top} Richest Noders</h3>
      <ol style={styles.list}>
        {richest_top.map((user, index) => (
          <li key={user.user_id} style={styles.listItem}>
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      {/* GP Statistics */}
      <p style={styles.stats}>
        <strong>Total GP in circulation:</strong> {total_gp.toLocaleString()}
      </p>
      <p style={styles.stats}>
        The top {limit_top} users hold {top_percentage.toFixed(2)}% of all the GP
      </p>
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111'
  },
  heading: {
    fontSize: '16px',
    fontWeight: 'bold',
    marginTop: '20px',
    marginBottom: '12px',
    color: '#38495e'
  },
  list: {
    paddingLeft: '30px',
    marginBottom: '12px'
  },
  listItem: {
    marginBottom: '4px'
  },
  divider: {
    border: 'none',
    borderTop: '1px solid #dee2e6',
    marginTop: '20px',
    marginBottom: '20px'
  },
  stats: {
    fontSize: '13px',
    marginTop: '12px',
    marginBottom: '8px'
  }
}

export default EverythingSRichestNoders
