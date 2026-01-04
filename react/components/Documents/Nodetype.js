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

  const sectionStyle = {
    marginBottom: '20px',
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '6px',
    border: '1px solid #dee2e6'
  }

  const headerStyle = {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    marginBottom: '10px',
    color: '#38495e',
    fontSize: '14px',
    fontWeight: 'bold'
  }

  const valueStyle = {
    color: '#495057',
    fontSize: '13px'
  }

  const emptyStyle = {
    color: '#6c757d',
    fontStyle: 'italic',
    fontSize: '13px'
  }

  const listStyle = {
    margin: '0',
    paddingLeft: '20px',
    listStyle: 'disc'
  }

  const listItemStyle = {
    marginBottom: '4px',
    fontSize: '13px'
  }

  const renderNodeList = (nodes, emptyText = 'none') => {
    if (nodes.length === 0) {
      return <span style={emptyStyle}>{emptyText}</span>
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
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${node_id}`}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            padding: '8px 16px',
            backgroundColor: '#4060b0',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '4px',
            fontSize: '13px',
            fontWeight: '500'
          }}
        >
          <FaList size={12} /> List Nodes of Type
        </a>
      </div>

      {/* Permissions Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaUsers size={16} /> Permissions
        </h4>

        <div style={{ display: 'grid', gap: '12px' }}>
          <div>
            <div style={headerStyle}>
              <FaUsers size={12} /> Authorized Readers
            </div>
            <div style={valueStyle}>
              {renderNodeList(readers)}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaUserPlus size={12} /> Authorized Creators
            </div>
            <div style={valueStyle}>
              {renderNodeList(writers)}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaTrash size={12} /> Authorized Deleters
            </div>
            <div style={valueStyle}>
              {renderNodeList(deleters)}
            </div>
          </div>
        </div>
      </div>

      {/* Configuration Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaCogs size={16} /> Configuration
        </h4>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
          <div>
            <div style={headerStyle}>
              <FaCopy size={12} /> Restrict Duplicates
            </div>
            <div style={valueStyle}>{getRestrictDupesText()}</div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaShieldAlt size={12} /> Verify Edits
            </div>
            <div style={valueStyle}>{verify_edits ? 'Yes' : 'No'}</div>
          </div>
        </div>
      </div>

      {/* Database Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaDatabase size={16} /> Database
        </h4>

        <div style={{ display: 'grid', gap: '12px' }}>
          <div>
            <div style={headerStyle}>
              <FaDatabase size={12} /> SQL Table{sql_tables.length !== 1 ? 's' : ''}
            </div>
            <div style={valueStyle}>
              {renderNodeList(sql_tables)}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaSitemap size={12} /> Extends Nodetype
            </div>
            <div style={valueStyle}>
              {extends_nodetype ? (
                <LinkNode nodeId={extends_nodetype.node_id} title={extends_nodetype.title} />
              ) : (
                <span style={emptyStyle}>none (base type)</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Related Nodes Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaFile size={16} /> Related Nodes
        </h4>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '20px' }}>
          <div>
            <div style={headerStyle}>
              <FaFile size={12} /> Relevant Pages
            </div>
            {pages.length > 0 ? (
              <ul style={listStyle}>
                {pages.map((page) => (
                  <li key={page.node_id} style={listItemStyle}>
                    <LinkNode nodeId={page.node_id} title={page.title} />
                  </li>
                ))}
              </ul>
            ) : (
              <div style={emptyStyle}>No pages</div>
            )}
          </div>

          <div>
            <div style={headerStyle}>
              <FaCogs size={12} /> Active Maintenances
            </div>
            {maintenances.length > 0 ? (
              <ul style={listStyle}>
                {maintenances.map((maint) => (
                  <li key={maint.node_id} style={listItemStyle}>
                    <LinkNode nodeId={maint.node_id} title={maint.title} />
                  </li>
                ))}
              </ul>
            ) : (
              <div style={emptyStyle}>No maintenance functions</div>
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
