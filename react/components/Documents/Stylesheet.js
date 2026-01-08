import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCss3Alt, FaInfoCircle, FaUser, FaClock, FaCheckCircle, FaTimesCircle, FaExternalLinkAlt, FaEdit, FaCopy, FaEye } from 'react-icons/fa'

/**
 * Stylesheet - Display page for stylesheet nodes (CSS themes)
 *
 * Stylesheets define visual themes for Everything2. This component displays:
 * - CSS content with syntax highlighting preview
 * - Metadata (author, creation date, supported status)
 * - CSS statistics (lines, size)
 * - Link to rendered CSS file
 * - Source map for developers
 * - Edit link (gods only)
 */
const Stylesheet = ({ data, user }) => {
  const [showFullCss, setShowFullCss] = useState(false)
  const [copied, setCopied] = useState(false)

  if (!data || !data.stylesheet) return null

  const { stylesheet, sourceMap, user: userData } = data
  const isDeveloper = user?.developer || user?.editor || userData?.is_admin
  const isAdmin = user?.admin || userData?.is_admin
  const {
    node_id,
    title,
    doctext,
    createtime,
    edittime,
    author,
    is_supported,
    css_length,
    css_lines,
    type_nodetype
  } = stylesheet

  // Format file size
  const formatSize = (bytes) => {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`
  }

  // Format date
  const formatDate = (dateStr) => {
    if (!dateStr || dateStr === '0000-00-00 00:00:00') return 'Unknown'
    try {
      return new Date(dateStr).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    } catch {
      return dateStr
    }
  }

  // Copy CSS to clipboard
  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(doctext)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch (err) {
      console.error('Failed to copy:', err)
    }
  }

  // Preview CSS (first 50 lines or full)
  const getCssPreview = () => {
    if (!doctext) return ''
    if (showFullCss) return doctext
    const lines = doctext.split('\n')
    if (lines.length <= 50) return doctext
    return lines.slice(0, 50).join('\n') + '\n/* ... truncated ... */'
  }

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
    gridRow: {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
      gap: '15px'
    },
    fieldLabel: {
      display: 'flex',
      alignItems: 'center',
      gap: '6px',
      color: '#38495e',
      fontSize: '13px',
      fontWeight: 'bold',
      marginBottom: '4px'
    },
    fieldValue: {
      color: '#495057',
      fontSize: '13px'
    },
    emptyValue: {
      color: '#6c757d',
      fontStyle: 'italic',
      fontSize: '13px'
    },
    supportedBadge: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '4px',
      padding: '4px 10px',
      borderRadius: '12px',
      fontSize: '12px',
      fontWeight: '500'
    },
    supportedYes: {
      backgroundColor: '#d4edda',
      color: '#155724'
    },
    supportedNo: {
      backgroundColor: '#fff3cd',
      color: '#856404'
    },
    codeContainer: {
      position: 'relative'
    },
    codeHeader: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '10px',
      flexWrap: 'wrap',
      gap: '10px'
    },
    codeActions: {
      display: 'flex',
      gap: '8px'
    },
    codeButton: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '4px',
      padding: '6px 12px',
      backgroundColor: 'transparent',
      color: '#4060b0',
      border: '1px solid #4060b0',
      borderRadius: '4px',
      fontSize: '12px',
      cursor: 'pointer'
    },
    codePreview: {
      fontFamily: '"Fira Code", "Monaco", "Consolas", monospace',
      fontSize: '12px',
      backgroundColor: '#1e1e1e',
      color: '#d4d4d4',
      padding: '16px',
      borderRadius: '6px',
      overflow: 'auto',
      maxHeight: showFullCss ? 'none' : '400px',
      whiteSpace: 'pre',
      lineHeight: '1.5',
      tabSize: 2
    },
    stats: {
      display: 'flex',
      gap: '20px',
      fontSize: '13px',
      color: '#6c757d'
    },
    stat: {
      display: 'flex',
      alignItems: 'center',
      gap: '4px'
    },
    cssLink: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: '6px',
      color: '#4060b0',
      textDecoration: 'none',
      fontSize: '13px'
    }
  }

  return (
    <div style={styles.container}>
      {/* Action Bar */}
      <div style={styles.actionBar}>
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${type_nodetype || 45}`}
          style={styles.actionButton}
        >
          <FaList size={12} /> List All Stylesheets
        </a>
        <a
          href="/title/theme%20nirvana"
          style={styles.actionButtonSecondary}
        >
          <FaCss3Alt size={12} /> Theme Browser
        </a>
        <a
          href={`/css/${node_id}.css`}
          target="_blank"
          rel="noopener noreferrer"
          style={styles.actionButtonSecondary}
        >
          <FaExternalLinkAlt size={12} /> View Raw CSS
        </a>
        {isAdmin && (
          <a
            href={`/node/${node_id}?displaytype=edit`}
            style={{ ...styles.actionButtonSecondary, backgroundColor: '#dc3545' }}
          >
            <FaEdit size={12} /> Edit (Admin)
          </a>
        )}
      </div>

      {/* About Section */}
      <div style={styles.section}>
        <h4 style={styles.sectionHeader}>
          <FaInfoCircle size={16} /> About Stylesheets
        </h4>
        <p style={{ ...styles.fieldValue, lineHeight: '1.6', margin: 0 }}>
          Stylesheets are CSS files that define the visual appearance of Everything2.
          Users can select their preferred stylesheet in their{' '}
          <a href="/title/Settings" style={{ color: '#4060b0' }}>Settings</a>.
          {is_supported ? (
            <span style={{ display: 'block', marginTop: '10px', color: '#155724' }}>
              <strong>This stylesheet is officially supported</strong> and appears in the user stylesheet selector.
            </span>
          ) : (
            <span style={{ display: 'block', marginTop: '10px', color: '#856404' }}>
              This stylesheet is not currently listed in the supported stylesheets.
            </span>
          )}
        </p>
      </div>

      {/* Metadata Section */}
      <div style={styles.section}>
        <h4 style={styles.sectionHeader}>
          <FaCss3Alt size={16} /> Stylesheet Info
        </h4>

        <div style={styles.gridRow}>
          <div>
            <div style={styles.fieldLabel}>
              <FaUser size={11} /> Author
            </div>
            <div style={styles.fieldValue}>
              {author ? (
                <LinkNode nodeId={author.node_id} title={author.title} type="user" />
              ) : (
                <span style={styles.emptyValue}>Unknown</span>
              )}
            </div>
          </div>

          <div>
            <div style={styles.fieldLabel}>
              <FaClock size={11} /> Created
            </div>
            <div style={styles.fieldValue}>
              {formatDate(createtime)}
            </div>
          </div>

          <div>
            <div style={styles.fieldLabel}>
              <FaClock size={11} /> Last Modified
            </div>
            <div style={styles.fieldValue}>
              {formatDate(edittime)}
            </div>
          </div>

          <div>
            <div style={styles.fieldLabel}>
              <FaCheckCircle size={11} /> Status
            </div>
            <div>
              <span style={{
                ...styles.supportedBadge,
                ...(is_supported ? styles.supportedYes : styles.supportedNo)
              }}>
                {is_supported ? (
                  <><FaCheckCircle size={10} /> Supported</>
                ) : (
                  <><FaTimesCircle size={10} /> Not Listed</>
                )}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* CSS Preview Section */}
      <div style={styles.section}>
        <div style={styles.codeHeader}>
          <h4 style={{ ...styles.sectionHeader, marginBottom: 0, borderBottom: 'none', paddingBottom: 0 }}>
            <FaCode size={16} /> CSS Content
          </h4>
          <div style={styles.stats}>
            <span style={styles.stat}>
              {css_lines} lines
            </span>
            <span style={styles.stat}>
              {formatSize(css_length)}
            </span>
          </div>
        </div>

        <div style={styles.codeContainer}>
          <div style={styles.codeActions}>
            <button style={styles.codeButton} onClick={handleCopy}>
              <FaCopy size={11} /> {copied ? 'Copied!' : 'Copy'}
            </button>
            {css_lines > 50 && (
              <button
                style={styles.codeButton}
                onClick={() => setShowFullCss(!showFullCss)}
              >
                <FaEye size={11} /> {showFullCss ? 'Show Less' : `Show All (${css_lines} lines)`}
              </button>
            )}
            <a
              href={`/css/${node_id}.css`}
              target="_blank"
              rel="noopener noreferrer"
              style={{ ...styles.codeButton, textDecoration: 'none' }}
            >
              <FaExternalLinkAlt size={11} /> Open File
            </a>
          </div>

          <pre style={styles.codePreview}>
            {getCssPreview() || '/* No CSS content */'}
          </pre>
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

export default Stylesheet
