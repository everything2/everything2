import React from 'react'
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
 *
 * Data comes from e2.pageheader (built by Application.pm buildPageheaderData)
 */
const PageHeader = ({ node, pageheader, user, children }) => {
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
        <h1 className="nodetitle" style={styles.title}>{node.title}</h1>
        {children}
      </div>

      {/* Created by - only for e2nodes and logged-in users */}
      {createdby && (
        <div style={styles.createdbyWrapper}>
          <span
            className="createdby"
            style={styles.createdby}
            title={`created by ${createdby.title}${createdby.createtime ? ` on ${createdby.createtime}` : ''}`}
          >
            created by <LinkNode node_id={createdby.node_id} title={createdby.title} />
          </span>
        </div>
      )}

      {/* Parent link - for writeups */}
      {parentLink && (
        <div className="topic" id="parentlink">
          <LinkNode node_id={parentLink.node_id} title={`See all of ${parentLink.title}`} />
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
              <LinkNode node_id={link.node_id} title={link.title} />
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
                <> (message alias for <LinkNode node_id={item.forwardTo.node_id} title={item.forwardTo.title} />)</>
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
  title: {
    margin: 0,
    border: 'none'
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
