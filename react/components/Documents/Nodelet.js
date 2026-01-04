import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaClock, FaCode, FaFolder, FaCogs, FaInfoCircle } from 'react-icons/fa'

/**
 * Nodelet - Display page for nodelet nodes
 *
 * Modeled after the Nodetype display component.
 * Shows nodelet documentation, configuration, and source map.
 */
const Nodelet = ({ data, user }) => {
  if (!data || !data.nodelet) return null

  const { nodelet, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    updateinterval = 0,
    parent_container,
    nlcode_preview,
    nltext_preview,
    has_react_component
  } = nodelet

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

  // Format update interval
  const formatUpdateInterval = (interval) => {
    if (!interval || interval === 0) {
      return 'No caching (updated every request)'
    }
    if (interval < 60) {
      return `${interval} second${interval !== 1 ? 's' : ''}`
    }
    if (interval < 3600) {
      const mins = Math.floor(interval / 60)
      return `${mins} minute${mins !== 1 ? 's' : ''}`
    }
    const hours = Math.floor(interval / 3600)
    return `${hours} hour${hours !== 1 ? 's' : ''}`
  }

  return (
    <div className="nodelet-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=9`}
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
          <FaList size={12} /> List All Nodelets
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About This Nodelet
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Nodelets are sidebar widgets that appear in the right column of Everything2 pages.
          They provide quick access to information and features like chat, new writeups, and user stats.
          {has_react_component ? (
            <span style={{ display: 'block', marginTop: '10px', color: '#22c55e' }}>
              <strong>This nodelet uses a React component for rendering.</strong>
            </span>
          ) : (
            <span style={{ display: 'block', marginTop: '10px', color: '#f59e0b' }}>
              This nodelet uses legacy Perl htmlcode for rendering.
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
              <FaClock size={12} /> Update Interval
            </div>
            <div style={valueStyle}>{formatUpdateInterval(updateinterval)}</div>
          </div>

          <div>
            <div style={headerStyle}>
              <FaFolder size={12} /> Parent Container
            </div>
            <div style={valueStyle}>
              {parent_container && parent_container !== 0 ? (
                <LinkNode nodeId={parent_container} title={`Node ${parent_container}`} />
              ) : (
                <span style={emptyStyle}>None (top-level nodelet)</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Code Preview Section (Developer only) */}
      {isDeveloper && (nlcode_preview || nltext_preview) && (
        <div style={sectionStyle}>
          <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
            <FaCode size={16} /> Code Preview
          </h4>

          {nlcode_preview && (
            <div style={{ marginBottom: nltext_preview ? '15px' : 0 }}>
              <div style={{ ...headerStyle, marginBottom: '8px' }}>
                <FaCode size={12} /> nlcode (Perl code)
              </div>
              <div style={codePreviewStyle}>
                {nlcode_preview}
              </div>
            </div>
          )}

          {nltext_preview && (
            <div>
              <div style={{ ...headerStyle, marginBottom: '8px' }}>
                <FaCode size={12} /> nltext (HTML template)
              </div>
              <div style={codePreviewStyle}>
                {nltext_preview}
              </div>
            </div>
          )}
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

export default Nodelet
