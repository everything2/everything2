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

  const containerClass = depth > 0
    ? 'debate__comment debate__comment--nested'
    : 'debate__comment'

  return (
    <div className={containerClass}>
      {/* Comment header */}
      <div className="debate__comment-header">
        {hasChildren && (
          <button
            onClick={() => setCollapsed(!collapsed)}
            className="debate__collapse-btn"
            title={collapsed ? 'Expand replies' : 'Collapse replies'}
          >
            {collapsed ? <FaChevronRight /> : <FaChevronDown />}
          </button>
        )}
        <a href={`/?node_id=${comment.node_id}`} className="debate__comment-title">
          {comment.title}
        </a>
        {comment.author && (
          <span className="debate__comment-author">
            by <LinkNode {...comment.author} type="user" />
          </span>
        )}
        {comment.createtime && (
          <span className="debate__comment-time">{comment.createtime}</span>
        )}
      </div>

      {/* Comment content (only in full mode) */}
      {isFullMode && comment.doctext && !collapsed && (
        <div
          className="debate__comment-content"
          dangerouslySetInnerHTML={{ __html: renderE2Content(comment.doctext).html }}
        />
      )}

      {/* Comment actions */}
      {!collapsed && (
        <div className="debate__comment-actions">
          {canReply && (
            <a href={`/?node_id=${comment.node_id}&displaytype=replyto`} className="debate__comment-action-link">
              <FaReply />
              reply
            </a>
          )}
        </div>
      )}

      {/* Nested children */}
      {hasChildren && !collapsed && (
        <div className="debate__comment-children">
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
        <div className="debate__collapsed-info">
          {comment.children.length} {comment.children.length === 1 ? 'reply' : 'replies'} hidden
        </div>
      )}
    </div>
  )
}

const Debatecomment = ({ data, user }) => {
  if (!data) return null

  // Permission denied view
  // User info comes from props (passed by DocumentComponent from e2.user)
  if (data.permission_denied) {
    return (
      <div className="debate">
        <div className="debate__permission-denied">
          <FaLock className="debate__permission-icon" />
          <h3>Permission Denied</h3>
          <p>You do not have access to view this discussion.</p>
          <p className="text-small text-muted">
            This discussion is restricted to members of a specific usergroup.
          </p>
          {user && !user.guest && (
            <p className="text-small text-muted">
              You are logged in as <strong>{user.title}</strong>.
            </p>
          )}
          {user && user.guest && (
            <p className="text-small text-muted">
              Please <a href="/title/log%20in" className="text-link">log in</a> to see if you have access.
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
    can_edit,
    can_reply,
    display_mode,
    is_root
  } = data

  return (
    <div className="debate">
      {/* Header with usergroup link */}
      <div className="debate__header">
        <FaComments className="debate__header-icon" />
        <div className="debate__header-info">
          <h1 className="debate__title">{debatecomment.title}</h1>
          {usergroup && (
            <span className="debate__usergroup-badge">
              <FaUsers />
              <LinkNode {...usergroup} type="usergroup" />
            </span>
          )}
        </div>
        <div className="debate__actions">
          {can_edit && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=edit`} className="debate__action-link">
              <FaEdit />
              edit
            </a>
          )}
          {can_reply && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=replyto`} className="debate__action-link">
              <FaReply />
              reply
            </a>
          )}
        </div>
      </div>

      {/* Navigation breadcrumb */}
      {!is_root && root && (
        <div className="debate__breadcrumb">
          <span>Thread:</span>{' '}
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
        <div className="debate__meta">
          <FaUser />
          Posted by: <LinkNode {...debatecomment.author} type="user" />
          {debatecomment.createtime && (
            <span className="debate__createtime"> on {debatecomment.createtime}</span>
          )}
        </div>
      )}

      {/* Main comment content */}
      {display_mode === 'full' && debatecomment.doctext && (
        <div className="debate__main-content">
          <div
            className="debate__doctext"
            dangerouslySetInnerHTML={{ __html: renderE2Content(debatecomment.doctext).html }}
          />
        </div>
      )}

      {/* Display mode indicator */}
      {display_mode === 'compact' && (
        <div className="debate__compact-notice">
          <a href={`/?node_id=${debatecomment.node_id}`}>View full thread with content</a>
        </div>
      )}

      {/* Replies section */}
      {children && children.length > 0 && (
        <div className="debate__replies">
          <h3 className="debate__replies-title">
            <FaReply />
            Replies ({children.length})
          </h3>
          <div className="debate__replies-list">
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
        <div className="debate__no-replies">
          <p>No replies yet.</p>
          {can_reply && (
            <a href={`/?node_id=${debatecomment.node_id}&displaytype=replyto`} className="debate__start-reply-link">
              Be the first to reply
            </a>
          )}
        </div>
      )}
    </div>
  )
}

export default Debatecomment
