import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaFolder, FaCogs, FaInfoCircle, FaBoxOpen } from 'react-icons/fa'

/**
 * Container - Display page for container nodes
 *
 * Containers are layout templates that hold other nodes.
 * Shows parent container info and contained nodes.
 */
const Container = ({ data, user }) => {
  if (!data || !data.container) return null

  const { container, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    parent_container,
    context_preview
  } = container

  return (
    <div className="container-display">
      {/* Quick Actions */}
      <div className="dev-display__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${container.type_nodetype || 15}`}
          className="dev-display__action-btn"
        >
          <FaList size={12} /> List All Containers
        </a>
      </div>

      {/* About Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaInfoCircle size={16} /> About Containers
        </h4>
        <p className="dev-display__text dev-display__text--description">
          Containers are layout templates that define how content is displayed on Everything2.
          They can contain HTML markup with placeholders for dynamic content.
          Containers can be nested within other containers via the parent container setting.
        </p>
      </div>

      {/* Configuration Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaCogs size={16} /> Configuration
        </h4>

        <div>
          <div className="dev-display__header">
            <FaFolder size={12} /> Parent Container
          </div>
          <div className="dev-display__text">
            {parent_container && parent_container !== 0 ? (
              <LinkNode nodeId={parent_container} title={`Container ${parent_container}`} />
            ) : (
              <span className="dev-display__text--empty">None (top-level container)</span>
            )}
          </div>
        </div>
      </div>

      {/* Context Preview Section (Developer only) */}
      {isDeveloper && context_preview && (
        <div className="dev-display__section">
          <h4 className="dev-display__header dev-display__header--section">
            <FaBoxOpen size={16} /> Context Preview
          </h4>
          <div className="dev-display__code-preview">
            {context_preview}
          </div>
        </div>
      )}

      {/* Developer Source Map */}
      {isDeveloper && sourceMap && (
        <SourceMapDisplay
          sourceMap={sourceMap}
          title={`Source Map: ${title}`}
          showContributeBox={true}
          showDescription={true}
        />
      )}
    </div>
  )
}

export default Container
