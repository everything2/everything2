import React from 'react'

/**
 * TopicArchive - Room topic change log
 * Styles in CSS: .topic-archive__*
 */
const TopicArchive = ({ data }) => {
  const archiveData = data || {}
  const {
    entries = [],
    startat = 0,
    pageSize = 50,
    totalCount = 0,
    hasNext,
    hasPrev,
    error,
  } = archiveData

  if (error) {
    return (
      <div className="topic-archive">
        <div className="topic-archive__header">
          <h1 className="topic-archive__title">Topic Archive</h1>
        </div>
        <div className="topic-archive__error">{error}</div>
      </div>
    )
  }

  const prevStart = Math.max(0, startat - pageSize)
  const nextStart = startat + pageSize

  const rangeStart = startat + 1
  const rangeEnd = Math.min(startat + entries.length, totalCount)

  return (
    <div className="topic-archive">
      <div className="topic-archive__header">
        <h1 className="topic-archive__title">Topic Archive</h1>
      </div>

      <p>Log of room topic changes from the E2 Gift Shop.</p>

      {entries.length === 0 ? (
        <div className="topic-archive__empty">No entries found.</div>
      ) : (
        <>
          <table className="topic-archive__table">
            <thead>
              <tr>
                <th className="topic-archive__th">Time</th>
                <th className="topic-archive__th">Details</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry, index) => (
                <tr key={index} className={index % 2 === 0 ? 'topic-archive__row--even' : 'topic-archive__row--odd'}>
                  <td className="topic-archive__td">
                    <span className="topic-archive__time">{entry.time}</span>
                  </td>
                  <td className="topic-archive__td" dangerouslySetInnerHTML={{ __html: entry.details }} />
                </tr>
              ))}
            </tbody>
          </table>

          <div className="topic-archive__pager">
            {hasPrev ? (
              <a href={`?startat=${prevStart}`} className="topic-archive__pager-link">
                Previous ({prevStart + 1}-{startat})
              </a>
            ) : (
              <span className="topic-archive__pager-disabled">Previous</span>
            )}

            <span>
              Showing {rangeStart}-{rangeEnd} of {totalCount}
            </span>

            {hasNext ? (
              <a href={`?startat=${nextStart}`} className="topic-archive__pager-link">
                Next ({nextStart + 1}-{Math.min(nextStart + pageSize, totalCount)})
              </a>
            ) : (
              <span className="topic-archive__pager-disabled">(end of list)</span>
            )}
          </div>
        </>
      )}
    </div>
  )
}

export default TopicArchive
