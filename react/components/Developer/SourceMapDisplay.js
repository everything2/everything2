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
        <div className="source-map__empty">
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
        return <FaCode size={14} className="source-map__icon--react" />
      case 'test':
        return <FaVial size={14} className="source-map__icon--test" />
      case 'page_class':
      case 'delegation':
        return <FaFileCode size={14} className="source-map__icon--perl" />
      case 'node_class':
        return <FaCogs size={14} className="source-map__icon--node" />
      case 'controller':
        return <FaFileCode size={14} className="source-map__icon--controller" />
      case 'database_table':
        return <FaDatabase size={14} className="source-map__icon--database" />
      default:
        return <FaBook size={14} className="source-map__icon--default" />
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
    <div className="source-map">
      <h3 className="source-map__title">
        <FaGithub size={18} /> {title || 'Developer Source Map'}
      </h3>

      {showDescription && (
        <p className="source-map__description">
          This shows the source code components that render this page. Click links to view or edit on GitHub.
        </p>
      )}

      <div className="source-map__components">
        {components.map((component, idx) => (
          <div key={idx} className="source-map__component">
            <div className="source-map__component-header">
              {getIconForType(component.type)}
              <div className="source-map__component-content">
                <div className="source-map__component-title-row">
                  {component.name && (
                    <span className="source-map__component-name">
                      {component.name}
                    </span>
                  )}
                  <span className="source-map__component-badge">
                    {getTypeLabel(component.type)}
                  </span>
                </div>
                {component.description && (
                  <div className="source-map__component-desc">
                    {component.description}
                  </div>
                )}
              </div>
            </div>

            <div className="source-map__path-box">
              <span className="source-map__path">{component.path}</span>
              <div className="source-map__actions">
                <a
                  href={getGithubUrl(component.path)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="source-map__btn source-map__btn--view"
                >
                  <FaGithub size={12} /> View
                </a>
                <a
                  href={getEditUrl(component.path)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="source-map__btn source-map__btn--edit"
                >
                  <FaExternalLinkAlt size={10} /> Edit
                </a>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Repository Info */}
      <div className="source-map__repo-info">
        <strong>Repository:</strong>{' '}
        <a
          href={githubRepo}
          target="_blank"
          rel="noopener noreferrer"
          className="source-map__repo-link"
        >
          {githubRepo}
        </a>
        {' | '}
        <strong>Branch:</strong> {branch}
        {' | '}
        <strong>Commit:</strong>{' '}
        <code className="source-map__commit-hash">
          {commitHash?.substring(0, 7)}
        </code>
      </div>

      {/* Contribute Box */}
      {showContributeBox && (
        <div className="source-map__contribute">
          <div className="source-map__contribute-title">
            Want to contribute?
          </div>
          <p className="source-map__contribute-text">
            Everything2 is open source! You can improve this by submitting a pull request on GitHub.
            See the{' '}
            <a
              href="https://github.com/everything2/everything2/blob/master/CONTRIBUTING.md"
              target="_blank"
              rel="noopener noreferrer"
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
