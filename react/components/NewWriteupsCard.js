import React from 'react'

/**
 * NewWriteupsCard - A card display of new writeups for front pages
 *
 * Used in: Guest Front Page (below hero), Welcome to Everything (first card)
 * Displays a simplified list of recent writeups with title, type, and author
 */
const NewWriteupsCard = ({ writeups = [], isMobile = false, limit = 10 }) => {
  const displayWriteups = writeups.slice(0, limit)

  if (displayWriteups.length === 0) {
    return null
  }

  const cardClass = isMobile
    ? 'new-writeups-card new-writeups-card--mobile'
    : 'new-writeups-card'

  return (
    <div className={cardClass}>
      <h3 className="new-writeups-card-header">New Writeups</h3>
      <div className="new-writeups-card-body">
        <ul className="new-writeups-list">
          {displayWriteups.map((entry, index) => {
            const parent = entry.parent
            const author = entry.author
            const writeuptype = entry.writeuptype

            return (
              <li
                key={entry.node_id || index}
                className="new-writeups-item"
              >
                <div>
                  {parent ? (
                    <a
                      href={`/title/${encodeURIComponent(parent.title)}`}
                      className="new-writeups-link"
                    >
                      {parent.title}
                    </a>
                  ) : (
                    <a
                      href={`/node/${entry.node_id}`}
                      className="new-writeups-link"
                    >
                      {entry.title}
                    </a>
                  )}
                  {writeuptype && (
                    <span className="new-writeups-type">({writeuptype})</span>
                  )}
                </div>
                {author && (
                  <div className="new-writeups-author">
                    by{' '}
                    <a
                      href={`/user/${encodeURIComponent(author.title)}`}
                      className="new-writeups-author-link"
                    >
                      {author.title}
                    </a>
                  </div>
                )}
              </li>
            )
          })}
        </ul>
        <div className="new-writeups-more">
          <a href="/title/Writeups%20By%20Type" className="new-writeups-more-link">
            more writeups
          </a>
        </div>
      </div>
    </div>
  )
}

export default NewWriteupsCard
