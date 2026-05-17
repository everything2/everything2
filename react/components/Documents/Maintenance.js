import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCogs, FaInfoCircle, FaWrench } from 'react-icons/fa'

/**
 * Maintenance - Display page for maintenance nodes
 *
 * Maintenance nodes define automated operations (create, update, delete)
 * that run on nodes of specific types. They contain Perl code that
 * executes during node lifecycle events.
 */
const Maintenance = ({ data, user }) => {
  if (!data || !data.maintenance) return null

  const { maintenance, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    maintain_nodetype,
    maintain_nodetype_title,
    maintaintype,
    code_preview,
    is_delegated
  } = maintenance

  // Get CSS modifier class for maintaintype
  const getMaintainTypeBadgeClass = (type) => {
    const baseClass = 'maintenance__badge'
    switch (type?.toLowerCase()) {
      case 'create': return `${baseClass} maintenance__badge--create`
      case 'update': return `${baseClass} maintenance__badge--update`
      case 'delete': return `${baseClass} maintenance__badge--delete`
      default: return baseClass
    }
  }

  return (
    <div className="maintenance-display">
      {/* Quick Actions */}
      <div className="dev-display__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${maintenance.type_nodetype || 17}`}
          className="dev-display__action-btn"
        >
          <FaList size={12} /> List All Maintenance Nodes
        </a>
      </div>

      {/* About Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaInfoCircle size={16} /> About Maintenance Nodes
        </h4>
        <p className="dev-display__text dev-display__text--description">
          Maintenance nodes define automated operations that run during node lifecycle events.
          They contain Perl code that executes when nodes of a specific type are created,
          updated, or deleted.
          {is_delegated && (
            <span className="dev-display__delegated-warning">
              <strong>This maintenance is delegated</strong> - its implementation has been moved
              to the codebase. To modify it, submit a pull request on GitHub.
            </span>
          )}
        </p>
      </div>

      {/* Configuration Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaCogs size={16} /> Configuration
        </h4>

        <div className="dev-display__grid">
          <div>
            <div className="dev-display__header">
              <FaWrench size={12} /> Maintains Nodetype
            </div>
            <div className="dev-display__text">
              {maintain_nodetype ? (
                <LinkNode nodeId={maintain_nodetype} title={maintain_nodetype_title || `Nodetype ${maintain_nodetype}`} />
              ) : (
                <span className="dev-display__text--empty">None</span>
              )}
            </div>
          </div>

          <div>
            <div className="dev-display__header">
              <FaCogs size={12} /> Operation Type
            </div>
            <div className="dev-display__text">
              {maintaintype ? (
                <span className={getMaintainTypeBadgeClass(maintaintype)}>
                  {maintaintype}
                </span>
              ) : (
                <span className="dev-display__text--empty">Not specified</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div className="dev-display__section">
          <h4 className="dev-display__header dev-display__header--section">
            <FaCode size={16} /> Code Preview
          </h4>
          <div className="dev-display__code-preview">
            {code_preview}
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

export default Maintenance
