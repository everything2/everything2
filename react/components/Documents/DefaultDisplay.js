import React from 'react'
import ParseLinks from '../ParseLinks'
import LinkNode from '../LinkNode'

/**
 * DefaultDisplay - Generic fallback display for node types without specific React components
 *
 * Shows basic node information: type, title, ID, author, and creation time.
 * Used when a nodetype doesn't have a dedicated display component but goes
 * through the controller routing system.
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
    <div className="default-display" style={{
      maxWidth: '800px',
      margin: '20px auto',
      padding: '20px',
      backgroundColor: '#f8f9f9',
      borderLeft: '4px solid #38495e',
      borderRadius: '4px'
    }}>
      <h2 style={{ color: '#38495e', marginTop: 0, marginBottom: '16px' }}>
        <ParseLinks text={`[${data.nodeTitle}]`} />
      </h2>

      <div style={{
        padding: '15px',
        backgroundColor: '#fff',
        border: '1px solid #d3d3d3',
        borderRadius: '4px',
        marginBottom: '20px'
      }}>
        <p style={{ margin: 0, color: '#507898' }}>
          <strong>Node Type:</strong> {data.nodeType}
        </p>
        <p style={{ margin: '10px 0 0 0', color: '#507898' }}>
          <strong>Node ID:</strong> {data.nodeId}
        </p>
        {data.author && (
          <p style={{ margin: '10px 0 0 0', color: '#507898' }}>
            <strong>Author:</strong>{' '}
            <LinkNode node_id={data.author.node_id} title={data.author.title} type="user" />
          </p>
        )}
        {data.createtime && (
          <p style={{ margin: '10px 0 0 0', color: '#507898' }}>
            <strong>Created:</strong> {data.createtime}
          </p>
        )}
      </div>

      {data.doctext && (
        <div style={{
          padding: '15px',
          backgroundColor: '#fff',
          border: '1px solid #d3d3d3',
          borderRadius: '4px',
          marginBottom: '20px'
        }}>
          <h3 style={{ color: '#38495e', margin: '0 0 12px 0', fontSize: '14px' }}>
            Content
          </h3>
          <div
            style={{ color: '#111', lineHeight: 1.6 }}
            dangerouslySetInnerHTML={{ __html: data.doctext }}
          />
        </div>
      )}

      {isAdmin && (
        <div style={{
          marginTop: '20px',
          padding: '12px',
          backgroundColor: '#e8f4f8',
          border: '1px solid #4060b0',
          borderRadius: '4px'
        }}>
          <p style={{ margin: 0, fontSize: '13px', color: '#38495e' }}>
            <strong>Admin:</strong>{' '}
            <a
              href={`/?node_id=${data.nodeId}&displaytype=basicedit`}
              style={{ color: '#4060b0', textDecoration: 'none' }}
            >
              Edit raw fields
            </a>
          </p>
        </div>
      )}

      {!data.doctext && (
        <p style={{
          fontSize: '14px',
          lineHeight: '1.6',
          color: '#507898',
          fontStyle: 'italic'
        }}>
          This node does not have a dedicated display interface. Use the raw field
          editor (basicedit) to view and modify the node's database fields.
        </p>
      )}
    </div>
  )
}

export default DefaultDisplay
