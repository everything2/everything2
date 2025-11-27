import React from 'react'
import Modal from 'react-modal'
import { FaGithub, FaCode, FaVial, FaFileCode, FaBook, FaExternalLinkAlt } from 'react-icons/fa'

const SourceMapModal = ({ isOpen, onClose, sourceMap, nodeTitle }) => {
  const { githubRepo, branch, commitHash, components } = sourceMap || {}

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
        return <FaCode size={16} style={{ color: '#61dafb' }} />
      case 'test':
        return <FaVial size={16} style={{ color: '#22c55e' }} />
      case 'page_class':
      case 'delegation':
        return <FaFileCode size={16} style={{ color: '#8b5cf6' }} />
      default:
        return <FaBook size={16} style={{ color: '#666' }} />
    }
  }

  const getTypeLabel = (type) => {
    const labels = {
      react_component: 'React Component',
      react_document: 'React Document',
      test: 'Test Suite',
      page_class: 'Perl Page Class',
      delegation: 'Delegation Module'
    }
    return labels[type] || type
  }

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onClose}
      ariaHideApp={false}
      contentLabel="Source Map"
      style={{
        content: {
          top: '50%',
          left: '50%',
          right: 'auto',
          bottom: 'auto',
          marginRight: '-50%',
          transform: 'translate(-50%, -50%)',
          minWidth: '600px',
          maxWidth: '800px',
          maxHeight: '80vh',
          overflow: 'auto'
        },
      }}
    >
      <div>
        <h2 style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#5bc0de', marginBottom: '8px' }}>
          <FaGithub size={24} /> Source Map: {nodeTitle}
        </h2>

        <p style={{ color: '#666', marginBottom: '20px', lineHeight: '1.6' }}>
          This shows the source code components that render this page. Click links to view or edit on GitHub.
        </p>

        {!components || components.length === 0 ? (
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
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {components.map((component, idx) => (
              <div
                key={idx}
                style={{
                  padding: '16px',
                  backgroundColor: '#f8f9fa',
                  border: '1px solid #dee2e6',
                  borderRadius: '6px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px' }}>
                  {getIconForType(component.type)}
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 'bold', fontSize: '14px', color: '#212529' }}>
                      {component.name}
                    </div>
                    <div style={{ fontSize: '12px', color: '#6c757d', marginTop: '2px' }}>
                      {component.description}
                    </div>
                  </div>
                </div>

                <div style={{
                  fontFamily: 'monospace',
                  fontSize: '12px',
                  color: '#495057',
                  backgroundColor: '#fff',
                  padding: '8px',
                  borderRadius: '3px',
                  marginBottom: '10px',
                  border: '1px solid #e9ecef'
                }}>
                  {component.path}
                </div>

                <div style={{ display: 'flex', gap: '8px' }}>
                  <a
                    href={getGithubUrl(component.path)}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '6px 12px',
                      backgroundColor: '#0969da',
                      color: 'white',
                      textDecoration: 'none',
                      borderRadius: '4px',
                      fontSize: '13px',
                      fontWeight: '500'
                    }}
                  >
                    <FaGithub size={14} /> View on GitHub
                  </a>
                  <a
                    href={getEditUrl(component.path)}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '6px 12px',
                      backgroundColor: '#22c55e',
                      color: 'white',
                      textDecoration: 'none',
                      borderRadius: '4px',
                      fontSize: '13px',
                      fontWeight: '500'
                    }}
                  >
                    <FaExternalLinkAlt size={12} /> Edit on GitHub
                  </a>
                </div>
              </div>
            ))}
          </div>
        )}

        <div style={{
          marginTop: '24px',
          padding: '16px',
          backgroundColor: '#fff3cd',
          border: '1px solid #ffc107',
          borderRadius: '4px'
        }}>
          <div style={{ fontWeight: 'bold', marginBottom: '8px', color: '#856404' }}>
            Want to contribute?
          </div>
          <p style={{ margin: '0 0 10px 0', fontSize: '14px', lineHeight: '1.6', color: '#856404' }}>
            Everything2 is open source! You can improve this page by submitting a pull request on GitHub.
            See the <a href="https://github.com/everything2/everything2/blob/master/CONTRIBUTING.md" target="_blank" rel="noopener noreferrer" style={{ color: '#0969da' }}>Contributing Guide</a> to get started.
          </p>
        </div>

        <div style={{ textAlign: 'right', marginTop: '20px' }}>
          <button
            type="button"
            onClick={onClose}
            style={{
              padding: '8px 20px',
              backgroundColor: '#6c757d',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            Close
          </button>
        </div>
      </div>
    </Modal>
  )
}

export default SourceMapModal
