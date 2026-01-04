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

  const badgeStyle = {
    display: 'inline-block',
    padding: '3px 8px',
    backgroundColor: '#6c757d',
    color: 'white',
    borderRadius: '3px',
    fontSize: '12px',
    fontWeight: '500',
    textTransform: 'uppercase'
  }

  // Color-code maintaintype
  const getMaintainTypeColor = (type) => {
    switch (type?.toLowerCase()) {
      case 'create': return '#28a745'
      case 'update': return '#007bff'
      case 'delete': return '#dc3545'
      default: return '#6c757d'
    }
  }

  return (
    <div className="maintenance-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${maintenance.type_nodetype || 17}`}
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
          <FaList size={12} /> List All Maintenance Nodes
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Maintenance Nodes
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Maintenance nodes define automated operations that run during node lifecycle events.
          They contain Perl code that executes when nodes of a specific type are created,
          updated, or deleted.
          {is_delegated && (
            <span style={{ display: 'block', marginTop: '10px', color: '#f59e0b' }}>
              <strong>This maintenance is delegated</strong> - its implementation has been moved
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
              <FaWrench size={12} /> Maintains Nodetype
            </div>
            <div style={valueStyle}>
              {maintain_nodetype ? (
                <LinkNode nodeId={maintain_nodetype} title={maintain_nodetype_title || `Nodetype ${maintain_nodetype}`} />
              ) : (
                <span style={emptyStyle}>None</span>
              )}
            </div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaCogs size={12} /> Operation Type
            </div>
            <div style={valueStyle}>
              {maintaintype ? (
                <span style={{ ...badgeStyle, backgroundColor: getMaintainTypeColor(maintaintype) }}>
                  {maintaintype}
                </span>
              ) : (
                <span style={emptyStyle}>Not specified</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && code_preview && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaCode size={16} /> Code Preview
          </h4>
          <div style={codePreviewStyle}>
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
