import React from 'react'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCogs, FaInfoCircle } from 'react-icons/fa'

/**
 * Htmlcode - Display page for htmlcode nodes
 *
 * Htmlcodes are reusable Perl code snippets that can be called
 * from templates and other code throughout the system.
 */
const Htmlcode = ({ data, user }) => {
  if (!data || !data.htmlcode) return null

  const { htmlcode, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    code_preview,
    is_delegated
  } = htmlcode

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
    <div className="htmlcode-display">
      {/* Quick Actions */}
      <div style={{ marginBottom: '20px' }}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${htmlcode.type_nodetype || 4}`}
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
          <FaList size={12} /> List All Htmlcodes
        </a>
      </div>

      {/* About Section */}
      <div style={sectionStyle}>
        <h4 style={{ ...headerStyle, marginBottom: '15px', fontSize: '15px', borderBottom: '1px solid #dee2e6', paddingBottom: '10px' }}>
          <FaInfoCircle size={16} /> About Htmlcodes
        </h4>
        <p style={{ ...valueStyle, lineHeight: '1.6', margin: 0 }}>
          Htmlcodes are reusable Perl code snippets that can be called from templates
          and other code throughout the Everything2 system. They provide a way to
          share common functionality across different parts of the site.
          {is_delegated && (
            <span style={{ display: 'block', marginTop: '10px', color: '#f59e0b' }}>
              <strong>This htmlcode is delegated</strong> - its implementation has been moved
              to the codebase. To modify it, submit a pull request on GitHub.
            </span>
          )}
        </p>
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

export default Htmlcode
