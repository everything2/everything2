import React from 'react'

/**
 * MyAchievements - Display user's earned and available achievements
 *
 * Shows:
 * - List of achievements the user has earned
 * - List of achievements still available to earn
 * - Progress statistics
 * - Debug mode for edev users (with ?debug=1)
 */
const MyAchievements = ({ data }) => {
  const {
    guest,
    achieved = [],
    unachieved = [],
    achieved_count,
    total_count,
    debug_mode,
    debug_data = {}
  } = data

  if (guest) {
    return (
      <div style={styles.container}>
        <p>If you logged in, you could see what achievements you've earned here.</p>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <p>
        You have reached <strong>{achieved_count}</strong> out of a total of{' '}
        <strong>{total_count}</strong> achievements:
      </p>

      {achieved.length > 0 && (
        <ul style={styles.list}>
          {achieved.map((achievement, index) => (
            <li key={achievement.id || index} dangerouslySetInnerHTML={{ __html: achievement.display }} />
          ))}
        </ul>
      )}

      <h3 style={styles.heading}>Achievements Left To Reach</h3>

      {unachieved.length > 0 ? (
        <ul style={styles.list}>
          {unachieved.map((achievement, index) => (
            <li key={achievement.id || index} dangerouslySetInnerHTML={{ __html: achievement.display }} />
          ))}
        </ul>
      ) : (
        <p style={styles.noAchievements}>
          <em>You've earned all available achievements!</em>
        </p>
      )}

      {debug_mode && (
        <div style={styles.debugSection}>
          <h3 style={styles.heading}>Debug: Achievements By Type</h3>
          <table style={styles.debugTable}>
            <thead>
              <tr>
                <th style={styles.th}>Type</th>
                <th style={styles.th}>Achieved</th>
                <th style={styles.th}>Total</th>
                <th style={styles.th}>Progress</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(debug_data).map(([type, stats]) => (
                <tr key={type}>
                  <td style={styles.td}>{type}</td>
                  <td style={styles.td}>{stats.achieved}</td>
                  <td style={styles.td}>{stats.total}</td>
                  <td style={styles.td}>
                    {stats.total > 0
                      ? `${((stats.achieved / stats.total) * 100).toFixed(1)}%`
                      : 'N/A'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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
  },
  list: {
    marginBottom: '20px',
    lineHeight: '1.8'
  },
  heading: {
    marginTop: '30px',
    marginBottom: '15px',
    color: '#38495e',
    fontSize: '16px',
    fontWeight: 'bold'
  },
  noAchievements: {
    padding: '20px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px',
    textAlign: 'center',
    color: '#507898'
  },
  debugSection: {
    marginTop: '40px',
    paddingTop: '30px',
    borderTop: '2px solid #38495e'
  },
  debugTable: {
    width: '100%',
    borderCollapse: 'collapse',
    marginTop: '15px',
    border: '1px solid #d3d3d3'
  },
  th: {
    backgroundColor: '#38495e',
    color: '#ffffff',
    padding: '10px',
    textAlign: 'left',
    border: '1px solid #38495e',
    fontWeight: 'bold'
  },
  td: {
    border: '1px solid #d3d3d3',
    padding: '8px'
  }
}

export default MyAchievements
