import React from 'react'
import { FaRss } from 'react-icons/fa'
import LinkNode from '../LinkNode'

/**
 * PageHeader - Renders the page header section with title, createdby, firmlinks, etc.
 *
 * This component replaces the server-side Mason/Perl rendering of:
 * - Node title (h1)
 * - "created by" attribution (e2nodes only, logged-in users)
 * - Parent link for writeups ("See all of [parent]")
 * - Firmlinks ("See also:" section)
 * - "Is also a" (when title matches other node types)
 * - RSS feed icon (optional, when feedUrl is provided)
 *
 * Data comes from e2.pageheader (built by Application.pm buildPageheaderData)
 */
const PageHeader = ({ node, pageheader, user, feedUrl, children }) => {
  if (!node) return null

  const { createdby, parentLink, firmlinks, isAlso } = pageheader || {}

  // Build "other writeups" text for parent link
  const getOtherWriteupsText = (count) => {
    if (count <= 0) return 'no other writeups in this node'
    if (count === 1) return 'there is 1 other writeup in this node'
    return `there are ${count} other writeups in this node`
  }

  return (
    <div id="pageheader">
      <div style={styles.titleRow}>
        <div style={styles.titleWithFeed}>
          <h1 className="nodetitle" style={styles.title}>{node.title}</h1>
          {feedUrl && (
            <a
              href={feedUrl}
              style={styles.feedIcon}
              title="Subscribe to RSS feed"
              aria-label="RSS Feed"
            >
              <FaRss />
            </a>
          )}
        </div>
        {children && <div style={styles.actionsWrapper}>{children}</div>}
      </div>

      {/* Created by - only for e2nodes and logged-in users */}
      {createdby && (
        <div style={styles.createdbyWrapper}>
          <span
            className="createdby"
            style={styles.createdby}
            title={`created by ${createdby.title}${createdby.createtime ? ` on ${createdby.createtime}` : ''}`}
          >
            created by <LinkNode id={createdby.node_id} display={createdby.title} />
          </span>
        </div>
      )}

      {/* Parent link - for writeups */}
      {parentLink && (
        <div className="topic" id="parentlink">
          <LinkNode id={parentLink.node_id} display={`See all of ${parentLink.title}`} />
          , {getOtherWriteupsText(parentLink.otherWriteupCount)}.
        </div>
      )}

      {/* Firmlinks - "See also:" section */}
      {firmlinks && firmlinks.length > 0 && (
        <div className="topic" id="firmlink">
          <strong>See also:</strong>{' '}
          {firmlinks.map((link, index) => (
            <React.Fragment key={link.node_id}>
              {index > 0 && ', '}
              <LinkNode id={link.node_id} display={link.title} />
              {link.note && ` ${link.note}`}
            </React.Fragment>
          ))}
        </div>
      )}

      {/* "Is also a" - when title matches other node types */}
      {isAlso && isAlso.length > 0 && (
        <div className="topic" id="isalso">
          ("{node.title}" is also a:{' '}
          {isAlso.map((item, index) => (
            <React.Fragment key={item.node_id}>
              {index > 0 && ', '}
              <a href={`/node/${item.node_id}`}>{item.type}</a>
              {item.forwardTo && (
                <> (message alias for <LinkNode id={item.forwardTo.node_id} display={item.forwardTo.title} />)</>
              )}
            </React.Fragment>
          ))}
          .)
        </div>
      )}
    </div>
  )
}

const styles = {
  titleRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    flexWrap: 'wrap',
    gap: '4px',
    borderBottom: '2px solid #507898',
    paddingBottom: '2px',
    marginBottom: '2px'
  },
  titleWithFeed: {
    display: 'flex',
    alignItems: 'baseline',
    gap: '8px',
    minWidth: 0,
    flex: '1 1 auto'
  },
  actionsWrapper: {
    // flex-grow: 1 means it will expand to fill available space on same row,
    // AND fill entire row when wrapped to its own line
    flex: '1 0 auto',
    display: 'flex',
    justifyContent: 'flex-end'
  },
  title: {
    margin: 0,
    border: 'none',
    fontSize: '24px',
    fontWeight: 'bold',
    lineHeight: '1.2'
  },
  feedIcon: {
    color: '#507898', // Muted Blue (Kernel Blue palette)
    fontSize: '20px',
    textDecoration: 'none',
    display: 'inline-flex',
    alignItems: 'center',
    padding: '4px', // Better touch target
    marginLeft: '4px',
    borderRadius: '4px'
  },
  createdbyWrapper: {
    textAlign: 'left'
  },
  createdby: {
    float: 'none',
    display: 'block'
  }
}

export default PageHeader
