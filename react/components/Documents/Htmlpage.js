import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCogs, FaInfoCircle, FaFolder, FaFileCode } from 'react-icons/fa'

/**
 * Htmlpage - Display page for htmlpage nodes
 *
 * Htmlpages are legacy page templates that define display/edit behaviors
 * for different node types. Most functionality has been migrated to
 * Everything::Page classes and React components.
 */
const Htmlpage = ({ data, user }) => {
  if (!data || !data.htmlpage) return null

  const { htmlpage, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    pagetype_nodetype,
    pagetype_title,
    displaytype,
    mimetype,
    parent_container,
    page_preview,
    is_delegated
  } = htmlpage

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
    maxHeight: '300px',
    whiteSpace: 'pre-wrap',
    wordBreak: 'break-all'
  }

  return (
    <div className="htmlpage-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${htmlpage.type_nodetype || 5}`}
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
          <FaList size={12} /> List All Htmlpages
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Htmlpages
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Htmlpages are legacy page templates that define how nodes of specific types
          are displayed or edited. Most htmlpage functionality has been migrated to
          Everything::Page classes and React document components.
          {is_delegated && (
            <span style={{ display: 'block', marginTop: '10px', color: '#f59e0b' }}>
              <strong>This htmlpage is delegated</strong> - its implementation has been moved
              to the codebase. To modify it, submit a pull request on GitHub.
            </span>
          )}
        </p>
      </div>

      {/* Configuration Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaCogs size={16} /> Configuration
        </h4>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
          <div>
            <div style={headerStyle}>
              <FaFileCode size={12} /> Page Type
            </div>
            <div style={valueStyle}>
              {pagetype_nodetype ? (
                <LinkNode nodeId={pagetype_nodetype} title={pagetype_title || `Nodetype ${pagetype_nodetype}`} />
              ) : (
                <span style={emptyStyle}>None</span>
              )}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaCode size={12} /> Display Type
            </div>
            <div style={valueStyle}>
              {displaytype || <span style={emptyStyle}>default</span>}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaFolder size={12} /> Parent Container
            </div>
            <div style={valueStyle}>
              {parent_container && parent_container !== 0 ? (
                <LinkNode nodeId={parent_container} title={`Container ${parent_container}`} />
              ) : (
                <span style={emptyStyle}>None</span>
              )}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaFileCode size={12} /> MIME Type
            </div>
            <div style={valueStyle}>
              {mimetype || <span style={emptyStyle}>text/html</span>}
            </div>
          </div>
        </div>
      </div>

      {/* Page Code Preview Section (Developer only) */}
      {isDeveloper && page_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaCode size={16} /> Page Code Preview
          </h4>
          <div style={codePreviewStyle}>
            {page_preview}
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

export default Htmlpage
