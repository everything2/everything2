import React from 'react'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'
import { FaComments, FaReply, FaEdit, FaUser, FaUsers, FaLock, FaChevronDown, FaChevronRight } from 'react-icons/fa'

/**
 * Debatecomment - Display page for usergroup discussion threads
 *
 * Debatecomments are threaded discussion nodes with:
 * - Usergroup-restricted access (only members can view/post)
 * - Nested reply structure (parent_debatecomment, root_debatecomment)
 * - Read/unread tracking via lastreaddebate table
 * - Display modes: full, compact
 */

// Recursive component for rendering nested comment threads
const CommentThread = ({ comment, depth = 0, displayMode, canReply }) => {
  const [collapsed, setCollapsed] = React.useState(false)
  const hasChildren = comment.children && comment.children.length > 0
  const isFullMode = displayMode === 'full'

  return (
    <div style={{
      ...styles.commentContainer,
      marginLeft: depth > 0 ? 24 : 0,
      borderLeft: depth > 0 ? '2px solid #e8f4f8' : 'none',
      paddingLeft: depth > 0 ? 16 : 0
    }}>
      {/* Comment header */}
      <div style={styles.commentHeader}>
        {hasChildren && (
          <button
            onClick={() => setCollapsed(!collapsed)}
            style={styles.collapseButton}
            title={collapsed ? 'Expand replies' : 'Collapse replies'}
          >
            {collapsed ? <FaChevronRight /> : <FaChevronDown />}
          </button>
        )}
        <a href={`/?node_id=${comment.node_id}`} style={styles.commentTitle}>
          {comment.title}
        </a>
        {comment.author && (
          <span style={styles.authorInfo}>
            by <LinkNode {...comment.author} type="user" />
          </span>
        )}
        {comment.createtime && (
          <span style={styles.timestamp}>{comment.createtime}</span>
        )}
      </div>

      {/* Comment content (only in full mode) */}
      {isFullMode && comment.doctext && !collapsed && (
        <div
          style={styles.commentContent}
          dangerouslySetInnerHTML={{ __html: renderE2Content(comment.doctext).html }}
        />
      )}

      {/* Comment actions */}
      {!collapsed && (
        <div style={styles.commentActions}>
          {canReply && (
            <a href={`/?node_id=${comment.node_id}&displaytype=replyto`} style={styles.actionLink}>
              <FaReply style={{ marginRight: 4 }} />
              reply
            </a>
          )}
        </div>
      )}

      {/* Nested children */}
      {hasChildren && !collapsed && (
        <div style={styles.childrenContainer}>
          {comment.children.map(child => (
            <CommentThread
              key={child.node_id}
              comment={child}
              depth={depth + 1}
              displayMode={displayMode}
              canReply={canReply}
            />
          ))}
        </div>
      )}

      {/* Collapsed indicator */}
      {hasChildren && collapsed && (
        <div style={styles.collapsedInfo}>
          {comment.children.length} {comment.children.length === 1 ? 'reply' : 'replies'} hidden
        </div>
      )}
    </div>
  )
}

const Debatecomment = ({ data }) => {
  if (!data) return null

  // Permission denied view
  if (data.permission_denied) {
    return (
      <div style={styles.container}>
        <div style={styles.permissionDenied}>
          <FaLock style={{ fontSize: 48, color: '#507898', marginBottom: 16 }} />
          <h3 style={{ color: '#38495e' }}>Permission Denied</h3>
          <p>You do not have access to view this discussion.</p>
          <p style={{ fontSize: 13, color: '#507898' }}>
            This discussion is restricted to members of a specific usergroup.
          </p>
          {data.user && !data.user.is_guest && (
            <p style={{ fontSize: 13, color: '#507898' }}>
              You are logged in as <strong>{data.user.title}</strong>.
            </p>
          )}
          {data.user && data.user.is_guest && (
            <p style={{ fontSize: 13, color: '#507898' }}>
              Please <a href="/title/log%20in" style={{ color: '#4060b0' }}>log in</a> to see if you have access.
            </p>
          )}
        </div>
      </div>
    )
  }

  const {
    debatecomment,
    root,
    usergroup,
    parent,
    children,
    can_access,
    can_edit,
    can_reply,
    display_mode,
    is_root,
    user
  } = data

  return (
    <div style={styles.container}>
      {/* Header with usergroup link */}
      <div style={styles.header}>
        <FaComments style={{ color: '#507898', marginRight: 8, fontSize: 24 }} />
        <div style={styles.headerInfo}>
          <h1 style={styles.title}>{debatecomment.title}</h1>
          {usergroup && (
            <span style={styles.usergroupBadge}>
              <FaUsers style={{ marginRight: 4 }} />
              <LinkNode {...usergroup} type="usergroup" />
            </span>
          )}
        </div>
        <div style={styles.actions}>
          {can_edit && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=edit`} style={styles.editLink}>
              <FaEdit style={{ marginRight: 4 }} />
              edit
            </a>
          )}
          {can_reply && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=replyto`} style={styles.replyLink}>
              <FaReply style={{ marginRight: 4 }} />
              reply
            </a>
          )}
        </div>
      </div>

      {/* Navigation breadcrumb */}
      {!is_root && root && (
        <div style={styles.breadcrumb}>
          <span style={{ color: '#666' }}>Thread:</span>{' '}
          <a href={`/?node_id=${root.node_id}`}>{root.title}</a>
          {parent && parent.node_id !== root.node_id && (
            <>
              {' '}&rsaquo;{' '}
              <a href={`/?node_id=${parent.node_id}`}>{parent.title}</a>
            </>
          )}
          {' '}&rsaquo;{' '}
          <strong>{debatecomment.title}</strong>
        </div>
      )}

      {/* Author info */}
      {debatecomment.author && (
        <div style={styles.meta}>
          <FaUser style={{ marginRight: 6, color: '#507898' }} />
          Posted by: <LinkNode {...debatecomment.author} type="user" />
          {debatecomment.createtime && (
            <span style={styles.createtime}> on {debatecomment.createtime}</span>
          )}
        </div>
      )}

      {/* Main comment content */}
      {display_mode === 'full' && debatecomment.doctext && (
        <div style={styles.mainContent}>
          <div
            style={styles.doctext}
            dangerouslySetInnerHTML={{ __html: renderE2Content(debatecomment.doctext).html }}
          />
        </div>
      )}

      {/* Display mode indicator */}
      {display_mode === 'compact' && (
        <div style={styles.compactNotice}>
          <a href={`/?node_id=${debatecomment.node_id}`}>View full thread with content</a>
        </div>
      )}

      {/* Replies section */}
      {children && children.length > 0 && (
        <div style={styles.repliesSection}>
          <h3 style={styles.sectionTitle}>
            <FaReply style={{ marginRight: 8 }} />
            Replies ({children.length})
          </h3>
          <div style={styles.repliesList}>
            {children.map(child => (
              <CommentThread
                key={child.node_id}
                comment={child}
                depth={0}
                displayMode={display_mode}
                canReply={can_reply}
              />
            ))}
          </div>
        </div>
      )}

      {/* No replies message */}
      {(!children || children.length === 0) && !!is_root && (
        <div style={styles.noReplies}>
          <p>No replies yet.</p>
          {can_reply && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=replyto`} style={styles.startReplyLink}>
              Be the first to reply
            </a>
          )}
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    maxWidth: 800,
    margin: '0 auto',
    padding: '16px 0'
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: 16,
    paddingBottom: 16,
    borderBottom: '2px solid #38495e',
    flexWrap: 'wrap',
    gap: 8
  },
  headerInfo: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    minWidth: 200,
    flexWrap: 'wrap'
  },
  title: {
    margin: 0,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#38495e'
  },
  usergroupBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    fontSize: 12,
    color: '#4060b0',
    backgroundColor: '#e8f4f8',
    padding: '2px 8px',
    borderRadius: 4
  },
  actions: {
    display: 'flex',
    gap: 12,
    alignItems: 'center'
  },
  editLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  replyLink: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#4060b0',
    textDecoration: 'none'
  },
  breadcrumb: {
    fontSize: 13,
    color: '#507898',
    marginBottom: 16,
    padding: '8px 12px',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  meta: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 14,
    color: '#38495e',
    marginBottom: 20
  },
  createtime: {
    color: '#666',
    marginLeft: 4
  },
  mainContent: {
    padding: 16,
    backgroundColor: '#fff',
    border: '1px solid #e8f4f8',
    borderRadius: 4,
    marginBottom: 20
  },
  doctext: {
    lineHeight: 1.6,
    color: '#38495e'
  },
  compactNotice: {
    padding: 12,
    backgroundColor: '#f8f9fa',
    borderRadius: 4,
    marginBottom: 20,
    textAlign: 'center',
    fontSize: 14
  },
  repliesSection: {
    marginTop: 24
  },
  sectionTitle: {
    display: 'flex',
    alignItems: 'center',
    fontSize: 16,
    fontWeight: 'bold',
    color: '#38495e',
    marginTop: 0,
    marginBottom: 16,
    paddingBottom: 8,
    borderBottom: '1px solid #e8f4f8'
  },
  repliesList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 16
  },
  noReplies: {
    padding: 20,
    textAlign: 'center',
    color: '#507898',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  startReplyLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  permissionDenied: {
    padding: 40,
    textAlign: 'center',
    color: '#507898',
    backgroundColor: '#f8f9fa',
    borderRadius: 4
  },
  // Comment thread styles
  commentContainer: {
    marginBottom: 12
  },
  commentHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    flexWrap: 'wrap'
  },
  collapseButton: {
    background: 'none',
    border: 'none',
    padding: 4,
    cursor: 'pointer',
    color: '#507898',
    display: 'flex',
    alignItems: 'center',
    fontSize: 12
  },
  commentTitle: {
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none'
  },
  authorInfo: {
    fontSize: 13,
    color: '#507898'
  },
  timestamp: {
    fontSize: 12,
    color: '#507898'
  },
  commentContent: {
    marginTop: 8,
    marginBottom: 8,
    paddingLeft: 24,
    lineHeight: 1.5,
    color: '#38495e'
  },
  commentActions: {
    marginTop: 4,
    marginBottom: 8,
    paddingLeft: 24
  },
  actionLink: {
    display: 'inline-flex',
    alignItems: 'center',
    fontSize: 12,
    color: '#507898',
    textDecoration: 'none'
  },
  childrenContainer: {
    marginTop: 12
  },
  collapsedInfo: {
    fontSize: 12,
    color: '#507898',
    fontStyle: 'italic',
    marginLeft: 24,
    marginTop: 4
  }
}

export default Debatecomment
