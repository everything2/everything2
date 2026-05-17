import React from 'react'
import ParseLinks from '../ParseLinks'

/**
 * SystemNode - Generic display for system node types (maintenance, etc.)
 *
 * Shows a user-friendly message about system nodes and provides
 * source map information for developers/admins to find the code.
 * Styles are in CSS classes (system-node__*)
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
    <div className="system-node">
      <h2 className="system-node__header">
        System Node: <ParseLinks text={`[${data.nodeTitle}]`} />
      </h2>

      <div className="system-node__info-box">
        <p className="system-node__info-row">
          <strong>Node Type:</strong> {data.nodeType}
        </p>
        <p className="system-node__info-row system-node__info-row--spaced">
          <strong>Node ID:</strong> {data.nodeId}
        </p>
      </div>

      <p className="system-node__description">
        This is a system node that contains code or configuration used internally
        by Everything2. System nodes are not meant for general viewing, but developers
        and administrators can inspect them for debugging and maintenance purposes.
      </p>

      {isDeveloper && data.sourceMap && data.sourceMap.components && data.sourceMap.components.length > 0 && (
        <div className="system-node__dev-box">
          <h3 className="system-node__dev-title">
            Developer Source Map
          </h3>

          {data.sourceMap.components.map((component, index) => (
            <div key={index} className="system-node__component">
              <div className="system-node__component-header">
                <span className="system-node__component-type">
                  {component.type.replace(/_/g, ' ')}
                </span>
                <span className="system-node__component-desc">
                  {component.description}
                </span>
              </div>
              <div className="system-node__component-path">
                <a
                  href={`${data.sourceMap.githubRepo}/blob/${data.sourceMap.branch}/${component.path}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="system-node__component-link"
                >
                  {component.path}
                </a>
              </div>
            </div>
          ))}

          <div className="system-node__repo-info">
            <strong>Repository:</strong>{' '}
            <a
              href={data.sourceMap.githubRepo}
              target="_blank"
              rel="noopener noreferrer"
              className="system-node__repo-link"
            >
              {data.sourceMap.githubRepo}
            </a>
            <br />
            <strong>Branch:</strong> {data.sourceMap.branch}
            <br />
            <strong>Commit:</strong>{' '}
            <code className="system-node__commit-hash">{data.sourceMap.commitHash}</code>
          </div>
        </div>
      )}

      {!isDeveloper && (
        <p className="system-node__help-text">
          Developer access is required to view source code information for this node.
        </p>
      )}
    </div>
  )
}

export default SystemNode
