import React from 'react'

/**
 * IronNoderProgress - Iron Noder challenge progress tracker
 * Used for both current year progress and historical stats
 * Shows all participants and their November writeups
 */
const IronNoderProgress = ({ data }) => {
  const {
    year,
    group_title,
    participants = [],
    stats = {},
    is_participant,
    is_historical,
    writeup_goal = 30,
    max_daylogs = 5,
    available_years = [],
    error
  } = data

  const [expandedUsers, setExpandedUsers] = React.useState({})

  // Error state
  if (error) {
    return (
      <div style={styles.container}>
        <h2 style={styles.header}>
          {is_historical ? 'Historical Iron Noder Stats' : `Iron Noder Progress for ${year}`}
        </h2>
        <div style={styles.error}>
          <p>{error}</p>
        </div>
        {Boolean(is_historical) && available_years.length > 0 && (
          <div style={styles.yearSelector}>
            <p>Available years:</p>
            {available_years.map(y => (
              <a key={y} href={`?year=${y}`} style={styles.yearLink}>{y}</a>
            ))}
          </div>
        )}
      </div>
    )
  }

  const toggleUser = (userId) => {
    setExpandedUsers(prev => ({
      ...prev,
      [userId]: !prev[userId]
    }))
  }

  const expandAll = () => {
    const allExpanded = {}
    participants.forEach(p => {
      allExpanded[p.user.node_id] = true
    })
    setExpandedUsers(allExpanded)
  }

  const collapseAll = () => {
    setExpandedUsers({})
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.header}>Iron Noder Progress for {year}</h2>

      {/* Year selector for historical page */}
      {Boolean(is_historical) && available_years.length > 0 && (
        <div style={styles.yearSelector}>
          <span style={styles.yearLabel}>View other years: </span>
          {available_years.map(y => (
            <a
              key={y}
              href={`?year=${y}`}
              style={{
                ...styles.yearLink,
                ...(y === year ? styles.yearLinkActive : {})
              }}
            >
              {y}
            </a>
          ))}
        </div>
      )}

      <div style={styles.intro}>
        <p>
          {is_historical
            ? `Historical statistics for the Iron Noder challenge of November ${year}.`
            : 'The Iron Noder challenge runs every November.'
          }
          {' '}Participants aim to write <strong>{writeup_goal} writeups</strong> during the month
          {is_historical ? '.' : ' to earn the Iron Noder achievement.'}
        </p>
        <p style={styles.note}>
          Note: A maximum of {max_daylogs} daylog entries count toward the total.
          {Boolean(is_historical) && group_title && (
            <span> Group: <a href={`/title/${encodeURIComponent(group_title)}`} style={styles.link}>{group_title}</a></span>
          )}
        </p>
      </div>

      {/* Controls */}
      <div style={styles.controls}>
        <button onClick={expandAll} style={styles.controlButton}>Expand All</button>
        <button onClick={collapseAll} style={styles.controlButton}>Collapse All</button>
      </div>

      {/* Participant List */}
      {participants.length === 0 ? (
        <div style={styles.emptyState}>
          <p>No Iron Noder participants found for {year}.</p>
        </div>
      ) : (
        <ul style={styles.participantList}>
          {participants.map((participant) => {
            const isExpanded = expandedUsers[participant.user.node_id]
            const progressPercent = Math.min(100, (participant.writeup_count / writeup_goal) * 100)

            return (
              <li key={participant.user.node_id} style={styles.participantItem}>
                <div
                  style={styles.participantHeader}
                  onClick={() => toggleUser(participant.user.node_id)}
                >
                  <span style={styles.expandIcon}>{isExpanded ? '▼' : '▶'}</span>
                  <a
                    href={`/?node_id=${participant.user.node_id}`}
                    style={styles.userLink}
                    onClick={(e) => e.stopPropagation()}
                  >
                    {participant.user.title}
                  </a>
                  <span style={styles.writeupCount}>
                    ({participant.writeup_count}
                    {participant.excess_daylogs > 0 && (
                      <span style={styles.daylogNote}>
                        {' '}ignoring {participant.excess_daylogs} daylog{participant.excess_daylogs > 1 ? 's' : ''} above limit
                      </span>
                    )}
                    )
                  </span>
                  {participant.is_iron ? (
                    <span style={styles.ironBadge} title="Iron Noder!">🏆</span>
                  ) : null}
                </div>

                {/* Progress bar */}
                <div style={styles.progressContainer}>
                  <div
                    style={{
                      ...styles.progressBar,
                      width: `${progressPercent}%`,
                      backgroundColor: participant.is_iron ? '#28a745' : '#4060b0'
                    }}
                  />
                </div>

                {/* Writeup list (expandable) */}
                {isExpanded && participant.writeups && participant.writeups.length > 0 && (
                  <ol style={styles.writeupList}>
                    {participant.writeups.map((wu) => (
                      <li
                        key={wu.node_id}
                        style={{
                          ...styles.writeupItem,
                          ...(wu.has_voted ? styles.votedWriteup : {})
                        }}
                      >
                        <a href={`/?node_id=${wu.parent_id}`} style={styles.writeupLink}>
                          {wu.parenttitle}
                        </a>
                      </li>
                    ))}
                  </ol>
                )}
              </li>
            )
          })}
        </ul>
      )}

      {/* Statistics */}
      {stats && stats.total_noders > 0 && (
        <div style={styles.statsSection}>
          <h3 style={styles.statsHeader}>{year} Statistics</h3>
          <div style={styles.statsGrid}>
            {Boolean(stats.your_writeups) && (
              <div style={styles.statItem}>
                <span style={styles.statLabel}>Your writeups:</span>
                <span style={styles.statValue}>{stats.your_writeups}</span>
              </div>
            )}
            {stats.vote_percentage !== undefined && (
              <div style={styles.statItem}>
                <span style={styles.statLabel}>You've voted on:</span>
                <span style={styles.statValue}>{stats.voted_writeups} writeups ({stats.vote_percentage}%)</span>
              </div>
            )}
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Minimum writeups:</span>
              <span style={styles.statValue}>{stats.min_writeups}</span>
            </div>
            {stats.min_writeups_positive !== null && stats.min_writeups_positive !== undefined && stats.min_writeups_positive !== stats.min_writeups && (
              <div style={styles.statItem}>
                <span style={styles.statLabel}>Positive minimum:</span>
                <span style={styles.statValue}>{stats.min_writeups_positive}</span>
              </div>
            )}
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Maximum writeups:</span>
              <span style={styles.statValue}>{stats.max_writeups}</span>
            </div>
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Average writeups:</span>
              <span style={styles.statValue}>{stats.average_writeups}</span>
            </div>
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Total writeups:</span>
              <span style={styles.statValue}>{stats.total_writeups}</span>
            </div>
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Total noders:</span>
              <span style={styles.statValue}>{stats.total_noders}</span>
            </div>
            <div style={styles.statItem}>
              <span style={styles.statLabel}>Noders with writeups:</span>
              <span style={styles.statValue}>{stats.noders_with_writeups}</span>
            </div>
            <div style={{ ...styles.statItem, ...styles.ironStat }}>
              <span style={styles.statLabel}>IRON NODERS:</span>
              <span style={styles.statValue}>{stats.iron_noders}</span>
            </div>
          </div>
        </div>
      )}

      <p style={styles.footer}>
        See also:{' '}
        {is_historical ? (
          <a href="/title/iron+noder+progress" style={styles.link}>Current Iron Noder Progress</a>
        ) : (
          <a href="/title/historical+iron+noder+stats" style={styles.link}>Historical Iron Noder Stats</a>
        )}
        {' '}| <a href="/title/ironnoders" style={styles.link}>Iron Noders Usergroup</a>
      </p>
    </div>
  )
}

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    color: '#38495e',
    marginBottom: '20px',
    borderBottom: '2px solid #38495e',
    paddingBottom: '10px'
  },
  yearSelector: {
    marginBottom: '20px',
    padding: '12px',
    background: '#f8f9f9',
    borderRadius: '4px',
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '8px'
  },
  yearLabel: {
    color: '#6c757d',
    fontSize: '13px'
  },
  yearLink: {
    padding: '4px 10px',
    fontSize: '13px',
    color: '#4060b0',
    textDecoration: 'none',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    background: '#fff'
  },
  yearLinkActive: {
    background: '#38495e',
    color: '#fff',
    borderColor: '#38495e'
  },
  intro: {
    marginBottom: '20px',
    color: '#38495e',
    lineHeight: '1.6'
  },
  note: {
    fontSize: '13px',
    color: '#6c757d',
    fontStyle: 'italic'
  },
  error: {
    padding: '20px',
    background: '#f8d7da',
    color: '#721c24',
    border: '1px solid #f5c6cb',
    borderRadius: '4px',
    marginBottom: '20px'
  },
  emptyState: {
    padding: '30px',
    textAlign: 'center',
    color: '#6c757d',
    background: '#f8f9f9',
    borderRadius: '4px'
  },
  controls: {
    marginBottom: '15px',
    display: 'flex',
    gap: '10px'
  },
  controlButton: {
    padding: '6px 12px',
    fontSize: '12px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    backgroundColor: '#f8f9f9',
    cursor: 'pointer',
    color: '#495057'
  },
  participantList: {
    listStyle: 'none',
    padding: 0,
    margin: 0
  },
  participantItem: {
    marginBottom: '12px',
    padding: '12px',
    background: '#f8f9f9',
    borderRadius: '4px',
    border: '1px solid #eee'
  },
  participantHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    cursor: 'pointer',
    fontSize: '15px'
  },
  expandIcon: {
    fontSize: '10px',
    color: '#6c757d',
    width: '12px'
  },
  userLink: {
    color: '#4060b0',
    textDecoration: 'none',
    fontWeight: '600'
  },
  writeupCount: {
    color: '#6c757d',
    fontSize: '14px'
  },
  daylogNote: {
    fontSize: '11px',
    fontStyle: 'italic'
  },
  ironBadge: {
    marginLeft: 'auto',
    fontSize: '18px'
  },
  progressContainer: {
    marginTop: '8px',
    height: '6px',
    backgroundColor: '#e9ecef',
    borderRadius: '3px',
    overflow: 'hidden'
  },
  progressBar: {
    height: '100%',
    borderRadius: '3px',
    transition: 'width 0.3s ease'
  },
  writeupList: {
    marginTop: '10px',
    paddingLeft: '30px',
    fontSize: '13px',
    lineHeight: '1.8'
  },
  writeupItem: {
    marginBottom: '2px'
  },
  votedWriteup: {
    opacity: 0.7
  },
  writeupLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  statsSection: {
    marginTop: '30px',
    padding: '20px',
    background: '#f8f9f9',
    borderRadius: '4px',
    border: '1px solid #dee2e6'
  },
  statsHeader: {
    fontSize: '16px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '15px',
    marginTop: 0
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
    gap: '10px'
  },
  statItem: {
    display: 'flex',
    justifyContent: 'space-between',
    padding: '6px 10px',
    background: '#fff',
    borderRadius: '4px',
    fontSize: '13px'
  },
  statLabel: {
    color: '#6c757d'
  },
  statValue: {
    fontWeight: '600',
    color: '#38495e'
  },
  ironStat: {
    background: '#d4edda',
    border: '1px solid #c3e6cb'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  footer: {
    fontSize: '12px',
    color: '#6c757d',
    textAlign: 'center',
    marginTop: '30px',
    paddingTop: '20px',
    borderTop: '1px solid #eee'
  }
}

export default IronNoderProgress
