import React from 'react'
import { FaGithub, FaCode, FaVial, FaFileCode, FaBook, FaDatabase, FaExternalLinkAlt, FaCogs } from 'react-icons/fa'

/**
 * SourceMapDisplay - Inline display of source code components
 *
 * Reusable component that shows the source files that implement a feature.
 * Used by nodetype display, developer nodelet, and other developer tools.
 */
const SourceMapDisplay = ({ sourceMap, title, showContributeBox = true, showDescription = false, showEmptyState = false }) => {
  const { githubRepo, branch, commitHash, components } = sourceMap || {}

  if (!components || components.length === 0) {
    if (showEmptyState) {
      return (
        <div style={{
          padding: '20px',
          backgroundColor: '#f5f5f5',
          border: '1px solid #ddd',
          borderRadius: '4px',
          textAlign: 'center',
          color: '#666'
        }}>
          No source components detected for this node type.
        </div>
      )
    }
    return null
  }

  const getGithubUrl = (path) => {
    return `${githubRepo}/blob/${commitHash}/${path}`
  }

  const getEditUrl = (path) => {
    return `${githubRepo}/edit/${branch}/${path}`
  }

  const getIconForType = (type) => {
    switch (type) {
      case 'react_component':
      case 'react_document':
        return <FaCode size={14} style={{ color: '#61dafb' }} />
      case 'test':
        return <FaVial size={14} style={{ color: '#22c55e' }} />
      case 'page_class':
      case 'delegation':
        return <FaFileCode size={14} style={{ color: '#8b5cf6' }} />
      case 'node_class':
        return <FaCogs size={14} style={{ color: '#f97316' }} />
      case 'controller':
        return <FaFileCode size={14} style={{ color: '#3b82f6' }} />
      case 'database_table':
        return <FaDatabase size={14} style={{ color: '#10b981' }} />
      default:
        return <FaBook size={14} style={{ color: '#666' }} />
    }
  }

  const getTypeLabel = (type) => {
    const labels = {
      react_component: 'React Component',
      react_document: 'React Document',
      test: 'Test Suite',
      page_class: 'Perl Page Class',
      delegation: 'Delegation Module',
      node_class: 'Node Class',
      controller: 'Controller',
      database_table: 'Database Table'
    }
    return labels[type] || type.replace(/_/g, ' ')
  }

  return (
    <div style={{
      marginTop: '30px',
      padding: '20px',
      backgroundColor: '#fff',
      border: '1px solid #4060b0',
      borderRadius: '6px'
    }}>
      <h3 style={{
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        color: '#38495e',
        marginTop: 0,
        marginBottom: '15px',
        fontSize: '16px'
      }}>
        <FaGithub size={18} /> {title || 'Developer Source Map'}
      </h3>

      {showDescription && (
        <p style={{ color: '#666', marginBottom: '15px', lineHeight: '1.5', fontSize: '13px' }}>
          This shows the source code components that render this page. Click links to view or edit on GitHub.
        </p>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {components.map((component, idx) => (
          <div
            key={idx}
            style={{
              padding: '12px',
              backgroundColor: '#f8f9fa',
              border: '1px solid #dee2e6',
              borderRadius: '4px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
              {getIconForType(component.type)}
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                  {component.name && (
                    <span style={{ fontWeight: 'bold', fontSize: '13px', color: '#212529' }}>
                      {component.name}
                    </span>
                  )}
                  <span style={{
                    display: 'inline-block',
                    padding: '2px 8px',
                    backgroundColor: '#38495e',
                    color: '#fff',
                    borderRadius: '3px',
                    fontSize: '10px',
                    fontWeight: 'bold',
                    textTransform: 'uppercase'
                  }}>
                    {getTypeLabel(component.type)}
                  </span>
                </div>
                {component.description && (
                  <div style={{ color: '#507898', fontSize: '12px', marginTop: '2px' }}>
                    {component.description}
                  </div>
                )}
              </div>
            </div>

            <div style={{
              fontFamily: 'monospace',
              fontSize: '12px',
              color: '#495057',
              backgroundColor: '#fff',
              padding: '8px 12px',
              borderRadius: '3px',
              marginBottom: '8px',
              border: '1px solid #e9ecef',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '8px'
            }}>
              <span style={{ wordBreak: 'break-all' }}>{component.path}</span>
              <div style={{ display: 'flex', gap: '6px', flexShrink: 0 }}>
                <a
                  href={getGithubUrl(component.path)}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '4px 8px',
                    backgroundColor: '#0969da',
                    color: 'white',
                    textDecoration: 'none',
                    borderRadius: '3px',
                    fontSize: '11px',
                    fontWeight: '500'
                  }}
                >
                  <FaGithub size={12} /> View
                </a>
                <a
                  href={getEditUrl(component.path)}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '4px 8px',
                    backgroundColor: '#22c55e',
                    color: 'white',
                    textDecoration: 'none',
                    borderRadius: '3px',
                    fontSize: '11px',
                    fontWeight: '500'
                  }}
                >
                  <FaExternalLinkAlt size={10} /> Edit
                </a>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Repository Info */}
      <div style={{
        marginTop: '15px',
        padding: '10px 12px',
        backgroundColor: '#f8f9f9',
        borderRadius: '3px',
        fontSize: '12px',
        color: '#507898'
      }}>
        <strong>Repository:</strong>{' '}
        <a
          href={githubRepo}
          target="_blank"
          rel="noopener noreferrer"
          style={{ color: '#4060b0', textDecoration: 'none' }}
        >
          {githubRepo}
        </a>
        {' | '}
        <strong>Branch:</strong> {branch}
        {' | '}
        <strong>Commit:</strong>{' '}
        <code style={{ fontSize: '11px', backgroundColor: '#eee', padding: '1px 4px', borderRadius: '2px' }}>
          {commitHash?.substring(0, 7)}
        </code>
      </div>

      {/* Contribute Box */}
      {showContributeBox && (
        <div style={{
          marginTop: '15px',
          padding: '12px',
          backgroundColor: '#fff3cd',
          border: '1px solid #ffc107',
          borderRadius: '4px'
        }}>
          <div style={{ fontWeight: 'bold', marginBottom: '4px', color: '#856404', fontSize: '13px' }}>
            Want to contribute?
          </div>
          <p style={{ margin: 0, fontSize: '12px', lineHeight: '1.5', color: '#856404' }}>
            Everything2 is open source! You can improve this by submitting a pull request on GitHub.
            See the{' '}
            <a
              href="https://github.com/everything2/everything2/blob/master/CONTRIBUTING.md"
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: '#0969da' }}
            >
              Contributing Guide
            </a>{' '}
            to get started.
          </p>
        </div>
      )}
    </div>
  )
}

export default SourceMapDisplay
