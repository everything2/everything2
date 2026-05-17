import React from 'react'
import ParseLinks from '../ParseLinks'
import LinkNode from '../LinkNode'

/**
 * DefaultDisplay - Generic fallback display for node types without specific React components
 *
 * Shows basic node information: type, title, ID, author, and creation time.
 * Used when a nodetype doesn't have a dedicated display component but goes
 * through the controller routing system.
 * Styles are shared with SystemNode CSS classes (system-node__*)
 *
 * Similar to SystemNode but simpler - no source map or developer info.
 *
 * Props:
 * - data.nodeType: The type of the node (e.g., "maintenance", "htmlcode")
 * - data.nodeTitle: The title of the node
 * - data.nodeId: The node ID
 * - data.author: Author object { node_id, title }
 * - data.createtime: Creation timestamp
 * - data.doctext: Optional document text content (rendered as HTML)
 */
const DefaultDisplay = ({ data, user }) => {
  const isAdmin = user?.admin

  return (
    <div className="default-display system-node">
      <h2 className="system-node__header">
        <ParseLinks text={`[${data.nodeTitle}]`} />
      </h2>

      <div className="system-node__info-box">
        <p className="system-node__info-row">
          <strong>Node Type:</strong> {data.nodeType}
        </p>
        <p className="system-node__info-row system-node__info-row--spaced">
          <strong>Node ID:</strong> {data.nodeId}
        </p>
        {data.author && (
          <p className="system-node__info-row system-node__info-row--spaced">
            <strong>Author:</strong>{' '}
            <LinkNode node_id={data.author.node_id} title={data.author.title} type="user" />
          </p>
        )}
        {data.createtime && (
          <p className="system-node__info-row system-node__info-row--spaced">
            <strong>Created:</strong> {data.createtime}
          </p>
        )}
      </div>

      {data.doctext && (
        <div className="system-node__content-box">
          <h3 className="system-node__content-title">
            Content
          </h3>
          <div
            className="system-node__content-text"
            dangerouslySetInnerHTML={{ __html: data.doctext }}
          />
        </div>
      )}

      {isAdmin && (
        <div className="system-node__admin-box">
          <p className="system-node__admin-text">
            <strong>Admin:</strong>{' '}
            <a
              href={`/?node_id=${data.nodeId}&displaytype=basicedit`}
              className="system-node__admin-link"
            >
              Edit raw fields
            </a>
          </p>
        </div>
      )}

      {!data.doctext && (
        <p className="system-node__help-text">
          This node does not have a dedicated display interface. Use the raw field
          editor (basicedit) to view and modify the node's database fields.
        </p>
      )}
    </div>
  )
}

export default DefaultDisplay
