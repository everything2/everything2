import React from 'react'

/**
 * IronNoderProgress - Iron Noder challenge progress tracker
 * Styles in CSS: .iron-noder__*
 *
 * Used for both current year progress and historical stats.
 * Shows all participants and their November writeups.
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
      <div className="iron-noder">
        <h2 className="iron-noder__header">
          {is_historical ? 'Historical Iron Noder Stats' : `Iron Noder Progress for ${year}`}
        </h2>
        <div className="iron-noder__error">
          <p>{error}</p>
        </div>
        {Boolean(is_historical) && available_years.length > 0 && (
          <div className="iron-noder__year-selector">
            <p>Available years:</p>
            {available_years.map(y => (
              <a key={y} href={`?year=${y}`} className="iron-noder__year-link">{y}</a>
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
    <div className="iron-noder">
      <h2 className="iron-noder__header">Iron Noder Progress for {year}</h2>

      {/* Year selector for historical page */}
      {Boolean(is_historical) && available_years.length > 0 && (
        <div className="iron-noder__year-selector">
          <span className="iron-noder__year-label">View other years: </span>
          {available_years.map(y => (
            <a
              key={y}
              href={`?year=${y}`}
              className={`iron-noder__year-link ${y === year ? 'iron-noder__year-link--active' : ''}`}
            >
              {y}
            </a>
          ))}
        </div>
      )}

      <div className="iron-noder__intro">
        <p>
          {is_historical
            ? `Historical statistics for the Iron Noder challenge of November ${year}.`
            : 'The Iron Noder challenge runs every November.'
          }
          {' '}Participants aim to write <strong>{writeup_goal} writeups</strong> during the month
          {is_historical ? '.' : ' to earn the Iron Noder achievement.'}
        </p>
        <p className="iron-noder__note">
          Note: A maximum of {max_daylogs} daylog entries count toward the total.
          {Boolean(is_historical) && group_title && (
            <span> Group: <a href={`/title/${encodeURIComponent(group_title)}`} className="iron-noder__link">{group_title}</a></span>
          )}
        </p>
      </div>

      {/* Controls */}
      <div className="iron-noder__controls">
        <button onClick={expandAll} className="iron-noder__control-button">Expand All</button>
        <button onClick={collapseAll} className="iron-noder__control-button">Collapse All</button>
      </div>

      {/* Participant List */}
      {participants.length === 0 ? (
        <div className="iron-noder__empty">
          <p>No Iron Noder participants found for {year}.</p>
        </div>
      ) : (
        <ul className="iron-noder__list">
          {participants.map((participant) => {
            const isExpanded = expandedUsers[participant.user.node_id]
            const progressPercent = Math.min(100, (participant.writeup_count / writeup_goal) * 100)

            return (
              <li key={participant.user.node_id} className="iron-noder__participant">
                <div
                  className="iron-noder__participant-header"
                  onClick={() => toggleUser(participant.user.node_id)}
                >
                  <span className="iron-noder__expand-icon">{isExpanded ? '▼' : '▶'}</span>
                  <a
                    href={`/?node_id=${participant.user.node_id}`}
                    className="iron-noder__user-link"
                    onClick={(e) => e.stopPropagation()}
                  >
                    {participant.user.title}
                  </a>
                  <span className="iron-noder__writeup-count">
                    ({participant.writeup_count}
                    {participant.excess_daylogs > 0 && (
                      <span className="iron-noder__daylog-note">
                        {' '}ignoring {participant.excess_daylogs} daylog{participant.excess_daylogs > 1 ? 's' : ''} above limit
                      </span>
                    )}
                    )
                  </span>
                  {participant.is_iron ? (
                    <span className="iron-noder__badge" title="Iron Noder!">🏆</span>
                  ) : null}
                </div>

                {/* Progress bar */}
                <div className="iron-noder__progress-container">
                  <div
                    className={`iron-noder__progress-bar ${participant.is_iron ? 'iron-noder__progress-bar--iron' : 'iron-noder__progress-bar--pending'}`}
                    style={{ width: `${progressPercent}%` }}
                  />
                </div>

                {/* Writeup list (expandable) */}
                {isExpanded && participant.writeups && participant.writeups.length > 0 && (
                  <ol className="iron-noder__writeup-list">
                    {participant.writeups.map((wu) => (
                      <li
                        key={wu.node_id}
                        className={`iron-noder__writeup-item ${wu.has_voted ? 'iron-noder__writeup-item--voted' : ''}`}
                      >
                        <a href={`/?node_id=${wu.parent_id}`} className="iron-noder__writeup-link">
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
        <div className="iron-noder__stats">
          <h3 className="iron-noder__stats-header">{year} Statistics</h3>
          <div className="iron-noder__stats-grid">
            {Boolean(stats.your_writeups) && (
              <div className="iron-noder__stat-item">
                <span className="iron-noder__stat-label">Your writeups:</span>
                <span className="iron-noder__stat-value">{stats.your_writeups}</span>
              </div>
            )}
            {stats.vote_percentage !== undefined && (
              <div className="iron-noder__stat-item">
                <span className="iron-noder__stat-label">You've voted on:</span>
                <span className="iron-noder__stat-value">{stats.voted_writeups} writeups ({stats.vote_percentage}%)</span>
              </div>
            )}
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Minimum writeups:</span>
              <span className="iron-noder__stat-value">{stats.min_writeups}</span>
            </div>
            {stats.min_writeups_positive !== null && stats.min_writeups_positive !== undefined && stats.min_writeups_positive !== stats.min_writeups && (
              <div className="iron-noder__stat-item">
                <span className="iron-noder__stat-label">Positive minimum:</span>
                <span className="iron-noder__stat-value">{stats.min_writeups_positive}</span>
              </div>
            )}
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Maximum writeups:</span>
              <span className="iron-noder__stat-value">{stats.max_writeups}</span>
            </div>
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Average writeups:</span>
              <span className="iron-noder__stat-value">{stats.average_writeups}</span>
            </div>
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Total writeups:</span>
              <span className="iron-noder__stat-value">{stats.total_writeups}</span>
            </div>
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Total noders:</span>
              <span className="iron-noder__stat-value">{stats.total_noders}</span>
            </div>
            <div className="iron-noder__stat-item">
              <span className="iron-noder__stat-label">Noders with writeups:</span>
              <span className="iron-noder__stat-value">{stats.noders_with_writeups}</span>
            </div>
            <div className="iron-noder__stat-item iron-noder__stat-item--iron">
              <span className="iron-noder__stat-label">IRON NODERS:</span>
              <span className="iron-noder__stat-value">{stats.iron_noders}</span>
            </div>
          </div>
        </div>
      )}

      <p className="iron-noder__footer">
        See also:{' '}
        {is_historical ? (
          <a href="/title/iron+noder+progress" className="iron-noder__link">Current Iron Noder Progress</a>
        ) : (
          <a href="/title/historical+iron+noder+stats" className="iron-noder__link">Historical Iron Noder Stats</a>
        )}
        {' '}| <a href="/title/ironnoders" className="iron-noder__link">Iron Noders Usergroup</a>
      </p>
    </div>
  )
}

export default IronNoderProgress
