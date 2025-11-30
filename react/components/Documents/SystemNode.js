import React from 'react'
import ParseLinks from '../ParseLinks'

/**
 * SystemNode - Generic display for system node types (maintenance, etc.)
 *
 * Shows a user-friendly message about system nodes and provides
 * source map information for developers/admins to find the code.
 *
 * Props:
 * - data.nodeType: The type of the node (e.g., "maintenance")
 * - data.nodeTitle: The title of the node
 * - data.nodeId: The node ID
 * - data.sourceMap: Source map information for developers
 * - user: Current user object
 */
const SystemNode = ({ data, user }) => {
  const isDeveloper = user?.developer || user?.admin

  return (
    <div className="system-node" style={{
      maxWidth: '800px',
      margin: '20px auto',
      padding: '20px',
      backgroundColor: '#f8f9f9',
      borderLeft: '4px solid #38495e',
      borderRadius: '4px'
    }}>
      <h2 style={{ color: '#333333', marginTop: 0 }}>
        System Node: <ParseLinks text={`[${data.nodeTitle}]`} />
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
      </div>

      <p style={{ fontSize: '14px', lineHeight: '1.6', color: '#111111' }}>
        This is a system node that contains code or configuration used internally
        by Everything2. System nodes are not meant for general viewing, but developers
        and administrators can inspect them for debugging and maintenance purposes.
      </p>

      {isDeveloper && data.sourceMap && data.sourceMap.components && data.sourceMap.components.length > 0 && (
        <div style={{
          marginTop: '20px',
          padding: '15px',
          backgroundColor: '#fff',
          border: '1px solid #4060b0',
          borderRadius: '4px'
        }}>
          <h3 style={{
            color: '#38495e',
            marginTop: 0,
            marginBottom: '15px',
            fontSize: '16px'
          }}>
            Developer Source Map
          </h3>

          {data.sourceMap.components.map((component, index) => (
            <div key={index} style={{ marginBottom: index < data.sourceMap.components.length - 1 ? '15px' : 0 }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                marginBottom: '5px'
              }}>
                <span style={{
                  display: 'inline-block',
                  padding: '2px 8px',
                  backgroundColor: '#38495e',
                  color: '#fff',
                  borderRadius: '3px',
                  fontSize: '11px',
                  fontWeight: 'bold',
                  marginRight: '10px',
                  textTransform: 'uppercase'
                }}>
                  {component.type.replace(/_/g, ' ')}
                </span>
                <span style={{ color: '#507898', fontSize: '13px' }}>
                  {component.description}
                </span>
              </div>
              <div style={{
                fontFamily: 'monospace',
                fontSize: '12px',
                padding: '8px 12px',
                backgroundColor: '#f8f9f9',
                border: '1px solid #d3d3d3',
                borderRadius: '3px',
                overflowX: 'auto'
              }}>
                <a
                  href={`${data.sourceMap.githubRepo}/blob/${data.sourceMap.branch}/${component.path}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#4060b0', textDecoration: 'none' }}
                >
                  {component.path}
                </a>
              </div>
            </div>
          ))}

          <div style={{
            marginTop: '15px',
            padding: '10px',
            backgroundColor: '#f8f9f9',
            borderRadius: '3px',
            fontSize: '12px',
            color: '#507898'
          }}>
            <strong>Repository:</strong>{' '}
            <a
              href={data.sourceMap.githubRepo}
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: '#4060b0', textDecoration: 'none' }}
            >
              {data.sourceMap.githubRepo}
            </a>
            <br />
            <strong>Branch:</strong> {data.sourceMap.branch}
            <br />
            <strong>Commit:</strong>{' '}
            <code style={{ fontSize: '11px' }}>{data.sourceMap.commitHash}</code>
          </div>
        </div>
      )}

      {!isDeveloper && (
        <p style={{
          marginTop: '20px',
          fontSize: '13px',
          color: '#507898',
          fontStyle: 'italic'
        }}>
          Developer access is required to view source code information for this node.
        </p>
      )}
    </div>
  )
}

export default SystemNode
