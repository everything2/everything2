import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaUsers, FaUserPlus, FaTrash, FaCopy, FaShieldAlt, FaDatabase, FaSitemap, FaFile, FaCogs } from 'react-icons/fa'

/**
 * Nodetype - Display page for nodetype nodes
 *
 * Migrated from Everything::Delegation::htmlpage::nodetype_display_page
 * Shows nodetype documentation, permissions, and configuration
 */
const Nodetype = ({ data, user }) => {
  if (!data || !data.nodetype) return null

  const { nodetype, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    sql_tables = [],
    extends_nodetype,
    pages = [],
    maintenances = [],
    readers = [],
    writers = [],
    deleters = [],
    restrictdupes,
    verify_edits
  } = nodetype

  // Format restrictdupes value
  const getRestrictDupesText = () => {
    if (restrictdupes === -1) {
      return 'Inherited from parent'
    }
    return restrictdupes ? 'Yes' : 'No'
  }

  const renderNodeList = (nodes, emptyText = 'none') => {
    if (nodes.length === 0) {
      return <span className="nodetype__empty">{emptyText}</span>
    }
    return nodes.map((node, index) => (
      <React.Fragment key={node.node_id}>
        {index > 0 && ', '}
        <LinkNode nodeId={node.node_id} title={node.title} />
      </React.Fragment>
    ))
  }

  return (
    <div className="nodetype-display">
      {/* Quick Actions */}
      <div className="nodetype__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${node_id}`}
          className="nodetype__action-btn"
        >
          <FaList size={12} /> List Nodes of Type
        </a>
      </div>

      {/* Permissions Section */}
      <div className="nodetype__section">
        <h4 className="nodetype__section-title">
          <FaUsers size={16} /> Permissions
        </h4>

        <div className="nodetype__grid">
          <div>
            <div className="nodetype__header">
              <FaUsers size={12} /> Authorized Readers
            </div>
            <div className="nodetype__value">
              {renderNodeList(readers)}
            </div>
          </div>

          <div>
            <div className="nodetype__header">
              <FaUserPlus size={12} /> Authorized Creators
            </div>
            <div className="nodetype__value">
              {renderNodeList(writers)}
            </div>
          </div>

          <div>
            <div className="nodetype__header">
              <FaTrash size={12} /> Authorized Deleters
            </div>
            <div className="nodetype__value">
              {renderNodeList(deleters)}
            </div>
          </div>
        </div>
      </div>

      {/* Configuration Section */}
      <div className="nodetype__section">
        <h4 className="nodetype__section-title">
          <FaCogs size={16} /> Configuration
        </h4>

        <div className="nodetype__grid nodetype__grid--config">
          <div>
            <div className="nodetype__header">
              <FaCopy size={12} /> Restrict Duplicates
            </div>
            <div className="nodetype__value">{getRestrictDupesText()}</div>
          </div>

          <div>
            <div className="nodetype__header">
              <FaShieldAlt size={12} /> Verify Edits
            </div>
            <div className="nodetype__value">{verify_edits ? 'Yes' : 'No'}</div>
          </div>
        </div>
      </div>

      {/* Database Section */}
      <div className="nodetype__section">
        <h4 className="nodetype__section-title">
          <FaDatabase size={16} /> Database
        </h4>

        <div className="nodetype__grid">
          <div>
            <div className="nodetype__header">
              <FaDatabase size={12} /> SQL Table{sql_tables.length !== 1 ? 's' : ''}
            </div>
            <div className="nodetype__value">
              {renderNodeList(sql_tables)}
            </div>
          </div>

          <div>
            <div className="nodetype__header">
              <FaSitemap size={12} /> Extends Nodetype
            </div>
            <div className="nodetype__value">
              {extends_nodetype ? (
                <LinkNode nodeId={extends_nodetype.node_id} title={extends_nodetype.title} />
              ) : (
                <span className="nodetype__empty">none (base type)</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Related Nodes Section */}
      <div className="nodetype__section">
        <h4 className="nodetype__section-title">
          <FaFile size={16} /> Related Nodes
        </h4>

        <div className="nodetype__grid nodetype__grid--related">
          <div>
            <div className="nodetype__header">
              <FaFile size={12} /> Relevant Pages
            </div>
            {pages.length > 0 ? (
              <ul className="nodetype__list">
                {pages.map((page) => (
                  <li key={page.node_id} className="nodetype__list-item">
                    <LinkNode nodeId={page.node_id} title={page.title} />
                  </li>
                ))}
              </ul>
            ) : (
              <div className="nodetype__empty">No pages</div>
            )}
          </div>

          <div>
            <div className="nodetype__header">
              <FaCogs size={12} /> Active Maintenances
            </div>
            {maintenances.length > 0 ? (
              <ul className="nodetype__list">
                {maintenances.map((maint) => (
                  <li key={maint.node_id} className="nodetype__list-item">
                    <LinkNode nodeId={maint.node_id} title={maint.title} />
                  </li>
                ))}
              </ul>
            ) : (
              <div className="nodetype__empty">No maintenance functions</div>
            )}
          </div>
        </div>
      </div>

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

export default Nodetype
