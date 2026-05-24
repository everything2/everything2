import React from 'react'
import WriteupEntry from './WriteupEntry'
import LinkNode from './LinkNode'

/**
 * NewWriteupsCard - A card display of new writeups for front pages
 *
 * Used in: Guest Front Page (below hero), Welcome to Everything (first card)
 *
 * Renders each writeup with the same `WriteupEntry` component the sidebar
 * `NewWriteups` nodelet uses, so links (title, type, author) behave identically
 * across surfaces — including the in-page `#AuthorName` / `#writeup_<id>` anchors
 * that E2NodeDisplay's hash handler uses to scroll to the specific writeup
 * (issue #4048).
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
        <ul className="infolist new-writeups-list">
          {displayWriteups.map((entry, index) => (
            <WriteupEntry
              entry={entry}
              key={entry.node_id || index}
              mode="full"
            />
          ))}
        </ul>
        <div className="new-writeups-more">
          <LinkNode
            type="superdoc"
            title="Writeups By Type"
            display="more writeups"
            className="new-writeups-more-link"
          />
        </div>
      </div>
    </div>
  )
}

export default NewWriteupsCard
