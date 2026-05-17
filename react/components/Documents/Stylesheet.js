import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCss3Alt, FaInfoCircle, FaUser, FaClock, FaCheckCircle, FaTimesCircle, FaExternalLinkAlt, FaEdit, FaCopy, FaEye } from 'react-icons/fa'

/**
 * Stylesheet - Display page for stylesheet nodes (CSS themes)
 * Styles in CSS: .stylesheet__*
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

  return (
    <div className="stylesheet">
      {/* Action Bar */}
      <div className="stylesheet__action-bar">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${type_nodetype || 45}`}
          className="stylesheet__button stylesheet__button--primary"
        >
          <FaList size={12} /> List All Stylesheets
        </a>
        <a
          href="/title/theme%20nirvana"
          className="stylesheet__button stylesheet__button--secondary"
        >
          <FaCss3Alt size={12} /> Theme Browser
        </a>
        <a
          href={`/css/${node_id}.css`}
          target="_blank"
          rel="noopener noreferrer"
          className="stylesheet__button stylesheet__button--secondary"
        >
          <FaExternalLinkAlt size={12} /> View Raw CSS
        </a>
        {isAdmin && (
          <a
            href={`/node/${node_id}?displaytype=edit`}
            className="stylesheet__button stylesheet__button--danger"
          >
            <FaEdit size={12} /> Edit (Admin)
          </a>
        )}
      </div>

      {/* About Section */}
      <div className="stylesheet__section">
        <h4 className="stylesheet__section-header">
          <FaInfoCircle size={16} /> About Stylesheets
        </h4>
        <p className="stylesheet__about-text">
          Stylesheets are CSS files that define the visual appearance of Everything2.
          Users can select their preferred stylesheet in their{' '}
          <a href="/title/Settings" className="stylesheet__link">Settings</a>.
          {is_supported ? (
            <span className="stylesheet__support-note stylesheet__support-note--supported">
              <strong>This stylesheet is officially supported</strong> and appears in the user stylesheet selector.
            </span>
          ) : (
            <span className="stylesheet__support-note stylesheet__support-note--unsupported">
              This stylesheet is not currently listed in the supported stylesheets.
            </span>
          )}
        </p>
      </div>

      {/* Metadata Section */}
      <div className="stylesheet__section">
        <h4 className="stylesheet__section-header">
          <FaCss3Alt size={16} /> Stylesheet Info
        </h4>

        <div className="stylesheet__grid">
          <div className="stylesheet__field">
            <div className="stylesheet__field-label">
              <FaUser size={11} /> Author
            </div>
            <div className="stylesheet__field-value">
              {author ? (
                <LinkNode nodeId={author.node_id} title={author.title} type="user" />
              ) : (
                <span className="stylesheet__empty-value">Unknown</span>
              )}
            </div>
          </div>

          <div className="stylesheet__field">
            <div className="stylesheet__field-label">
              <FaClock size={11} /> Created
            </div>
            <div className="stylesheet__field-value">
              {formatDate(createtime)}
            </div>
          </div>

          <div className="stylesheet__field">
            <div className="stylesheet__field-label">
              <FaClock size={11} /> Last Modified
            </div>
            <div className="stylesheet__field-value">
              {formatDate(edittime)}
            </div>
          </div>

          <div className="stylesheet__field">
            <div className="stylesheet__field-label">
              <FaCheckCircle size={11} /> Status
            </div>
            <div>
              <span className={`stylesheet__badge ${is_supported ? 'stylesheet__badge--supported' : 'stylesheet__badge--unsupported'}`}>
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
      <div className="stylesheet__section">
        <div className="stylesheet__code-header">
          <h4 className="stylesheet__section-header stylesheet__section-header--inline">
            <FaCode size={16} /> CSS Content
          </h4>
          <div className="stylesheet__stats">
            <span className="stylesheet__stat">
              {css_lines} lines
            </span>
            <span className="stylesheet__stat">
              {formatSize(css_length)}
            </span>
          </div>
        </div>

        <div className="stylesheet__code-container">
          <div className="stylesheet__code-actions">
            <button className="stylesheet__code-button" onClick={handleCopy}>
              <FaCopy size={11} /> {copied ? 'Copied!' : 'Copy'}
            </button>
            {css_lines > 50 && (
              <button
                className="stylesheet__code-button"
                onClick={() => setShowFullCss(!showFullCss)}
              >
                <FaEye size={11} /> {showFullCss ? 'Show Less' : `Show All (${css_lines} lines)`}
              </button>
            )}
            <a
              href={`/css/${node_id}.css`}
              target="_blank"
              rel="noopener noreferrer"
              className="stylesheet__code-button"
            >
              <FaExternalLinkAlt size={11} /> Open File
            </a>
          </div>

          <pre className={`stylesheet__code-preview ${showFullCss ? 'stylesheet__code-preview--expanded' : ''}`}>
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
