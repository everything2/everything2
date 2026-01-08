import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaCode, FaUser, FaCopy, FaCheck, FaEdit, FaProjectDiagram } from 'react-icons/fa'

/**
 * Schema - Display page for schema nodes (XML schema definitions)
 *
 * Schemas define XML validation rules and extend the ticker nodetype.
 * Only one schema exists: "default xmltrue schema"
 *
 * Features:
 * - Display XML schema content with line numbers
 * - Show schema metadata (author, extends)
 * - Copy to clipboard functionality
 * - Admin: basicedit for raw editing
 * - Source map for developers
 */
const Schema = ({ data, user }) => {
  const { schema, sourceMap, user: userData } = data || {}
  const [copied, setCopied] = useState(false)

  if (!schema) return null

  const isDeveloper = user?.developer || user?.editor || userData?.is_admin
  const isAdmin = user?.admin || userData?.is_admin

  const {
    node_id,
    title,
    doctext,
    author,
    extends: schemaExtends
  } = schema

  // Copy schema content to clipboard
  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(doctext || '')
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error('Failed to copy:', err)
    }
  }

  // Add line numbers to code
  const formatCode = (code) => {
    if (!code) return []
    return code.split('\n')
  }

  const lines = formatCode(doctext)

  const styles = {
    container: {
      maxWidth: '1000px',
      margin: '0 auto',
      padding: '0'
    },
    actionBar: {
      display: 'flex',
      gap: '10px',
      marginBottom: '20px',
      flexWrap: 'wrap'
    },
    actionButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      backgroundColor: '#4060b0',
      color: 'white',
      textDecoration: 'none',
      borderRadius: '4px',
      fontSize: '13px',
      fontWeight: '500',
      border: 'none',
      cursor: 'pointer'
    },
    actionButtonSecondary: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '8px 16px',
      backgroundColor: '#507898',
      color: 'white',
      textDecoration: 'none',
      borderRadius: '4px',
      fontSize: '13px',
      fontWeight: '500',
      border: 'none',
      cursor: 'pointer'
    },
    section: {
      marginBottom: '20px',
      padding: '15px',
      backgroundColor: '#f8f9fa',
      borderRadius: '6px',
      border: '1px solid #dee2e6'
    },
    sectionHeader: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      marginBottom: '15px',
      color: '#38495e',
      fontSize: '15px',
      fontWeight: 'bold',
      borderBottom: '1px solid #dee2e6',
      paddingBottom: '10px'
    },
    infoGrid: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
      gap: '15px'
    },
    infoItem: {
      display: 'flex',
      flexDirection: 'column',
      gap: '4px'
    },
    infoLabel: {
      fontSize: '12px',
      color: '#507898',
      fontWeight: '500',
      textTransform: 'uppercase'
    },
    infoValue: {
      fontSize: '14px',
      color: '#333'
    },
    codeSection: {
      marginBottom: '20px'
    },
    codeHeader: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '10px'
    },
    codeTitle: {
      display: 'flex',
      alignItems: 'center',
      gap: '8px',
      color: '#38495e',
      fontSize: '15px',
      fontWeight: 'bold'
    },
    copyButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      padding: '6px 12px',
      backgroundColor: copied ? '#28a745' : '#6c757d',
      color: 'white',
      border: 'none',
      borderRadius: '4px',
      fontSize: '12px',
      cursor: 'pointer',
      transition: 'background-color 0.2s'
    },
    codeContainer: {
      backgroundColor: '#1e1e1e',
      borderRadius: '6px',
      overflow: 'auto',
      maxHeight: '500px',
      border: '1px solid #333'
    },
    codeTable: {
      width: '100%',
      borderCollapse: 'collapse',
      fontFamily: 'monospace',
      fontSize: '13px'
    },
    lineNumber: {
      padding: '2px 12px',
      textAlign: 'right',
      color: '#858585',
      backgroundColor: '#252526',
      borderRight: '1px solid #333',
      userSelect: 'none',
      minWidth: '40px'
    },
    codeLine: {
      padding: '2px 12px',
      color: '#d4d4d4',
      whiteSpace: 'pre-wrap',
      wordBreak: 'break-all'
    },
    lineCount: {
      fontSize: '13px',
      color: '#666'
    },
    emptyState: {
      padding: '40px 20px',
      textAlign: 'center',
      color: '#666',
      fontStyle: 'italic',
      backgroundColor: '#f5f5f5',
      borderRadius: '6px'
    },
    aboutText: {
      fontSize: '14px',
      color: '#495057',
      lineHeight: '1.6',
      margin: 0
    }
  }

  return (
    <div style={styles.container}>
      {/* Action Bar */}
      <div style={styles.actionBar}>
        {isAdmin && (
          <a
            href={`/node/${node_id}?displaytype=edit`}
            style={{ ...styles.actionButton, backgroundColor: '#dc3545' }}
          >
            <FaEdit size={12} /> Edit (Admin)
          </a>
        )}
      </div>

      {/* About Section */}
      <div style={styles.section}>
        <h4 style={styles.sectionHeader}>
          <FaProjectDiagram size={16} /> About Schemas
        </h4>
        <p style={styles.aboutText}>
          Schemas define XML validation rules for the site's XML output formats.
          They are used by the xmltrue display type to validate generated XML content.
          This schema extends the ticker nodetype, which itself extends document.
        </p>
      </div>

      {/* Schema Info Section */}
      <div style={styles.section}>
        <h4 style={styles.sectionHeader}>
          <FaCode size={16} /> Schema Information
        </h4>
        <div style={styles.infoGrid}>
          <div style={styles.infoItem}>
            <span style={styles.infoLabel}>Title</span>
            <span style={styles.infoValue}>{title}</span>
          </div>
          <div style={styles.infoItem}>
            <span style={styles.infoLabel}>Maintainer</span>
            <span style={styles.infoValue}>
              {author && author.node_id > 0 ? (
                <LinkNode nodeId={author.node_id} title={author.title} />
              ) : (
                <em style={{ color: '#999' }}>Unknown</em>
              )}
            </span>
          </div>
          {schemaExtends && (
            <div style={styles.infoItem}>
              <span style={styles.infoLabel}>Extends</span>
              <span style={styles.infoValue}>
                <LinkNode nodeId={schemaExtends.node_id} title={schemaExtends.title} />
              </span>
            </div>
          )}
          <div style={styles.infoItem}>
            <span style={styles.infoLabel}>Lines</span>
            <span style={styles.infoValue}>{lines.length}</span>
          </div>
        </div>
      </div>

      {/* Schema Content Section */}
      <div style={styles.codeSection}>
        <div style={styles.codeHeader}>
          <span style={styles.codeTitle}>
            <FaCode size={14} /> Schema Content
          </span>
          {doctext && (
            <button onClick={handleCopy} style={styles.copyButton}>
              {copied ? <FaCheck size={12} /> : <FaCopy size={12} />}
              {copied ? 'Copied!' : 'Copy'}
            </button>
          )}
        </div>

        {doctext ? (
          <div style={styles.codeContainer}>
            <table style={styles.codeTable}>
              <tbody>
                {lines.map((line, idx) => (
                  <tr key={idx}>
                    <td style={styles.lineNumber}>{idx + 1}</td>
                    <td style={styles.codeLine}>{line || ' '}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div style={styles.emptyState}>
            No schema content defined.
          </div>
        )}
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

export default Schema
