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

  const codePreviewStyle = {
    fontFamily: 'monospace',
    fontSize: '12px',
    backgroundColor: '#1e1e1e',
    color: '#d4d4d4',
    padding: '12px',
    borderRadius: '4px',
    overflow: 'auto',
    maxHeight: '200px',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all'
  }

  return (
    <div className="container-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${container.type_nodetype || 15}`}
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
          <FaList size={12} /> List All Containers
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Containers
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Containers are layout templates that define how content is displayed on Everything2.
          They can contain HTML markup with placeholders for dynamic content.
          Containers can be nested within other containers via the parent container setting.
        </p>
      </div>

      {/* Configuration Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaCogs size={16} /> Configuration
        </h4>

        <div>
          <div style={headerStyle}>
            <FaFolder size={12} /> Parent Container
          </div>
          <div style={valueStyle}>
            {parent_container && parent_container !== 0 ? (
              <LinkNode nodeId={parent_container} title={`Container ${parent_container}`} />
            ) : (
              <span style={emptyStyle}>None (top-level container)</span>
            )}
          </div>
        </div>
      </div>

      {/* Context Preview Section (Developer only) */}
      {isDeveloper && context_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaBoxOpen size={16} /> Context Preview
          </h4>
          <div style={codePreviewStyle}>
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
