import React, { useState } from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaCode, FaUser, FaCopy, FaCheck, FaEdit, FaProjectDiagram } from 'react-icons/fa'

/**
 * Schema - Display page for schema nodes (XML schema definitions)
 * Styles in CSS: .schema__*
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

  return (
    <div className="schema">
      {/* Action Bar */}
      <div className="schema__action-bar">
        {!!isAdmin && (
          <a
            href={`/node/${node_id}?displaytype=edit`}
            className="schema__action-button schema__action-button--admin"
          >
            <FaEdit size={12} /> Edit (Admin)
          </a>
        )}
      </div>

      {/* About Section */}
      <div className="schema__section">
        <h4 className="schema__section-header">
          <FaProjectDiagram size={16} /> About Schemas
        </h4>
        <p className="schema__about-text">
          Schemas define XML validation rules for the site's XML output formats.
          They are used by the xmltrue display type to validate generated XML content.
          This schema extends the ticker nodetype, which itself extends document.
        </p>
      </div>

      {/* Schema Info Section */}
      <div className="schema__section">
        <h4 className="schema__section-header">
          <FaCode size={16} /> Schema Information
        </h4>
        <div className="schema__info-grid">
          <div className="schema__info-item">
            <span className="schema__info-label">Title</span>
            <span className="schema__info-value">{title}</span>
          </div>
          <div className="schema__info-item">
            <span className="schema__info-label">Maintainer</span>
            <span className="schema__info-value">
              {author && author.node_id > 0 ? (
                <LinkNode nodeId={author.node_id} title={author.title} />
              ) : (
                <em className="schema__unknown-author">Unknown</em>
              )}
            </span>
          </div>
          {schemaExtends && (
            <div className="schema__info-item">
              <span className="schema__info-label">Extends</span>
              <span className="schema__info-value">
                <LinkNode nodeId={schemaExtends.node_id} title={schemaExtends.title} />
              </span>
            </div>
          )}
          <div className="schema__info-item">
            <span className="schema__info-label">Lines</span>
            <span className="schema__info-value">{lines.length}</span>
          </div>
        </div>
      </div>

      {/* Schema Content Section */}
      <div className="schema__code-section">
        <div className="schema__code-header">
          <span className="schema__code-title">
            <FaCode size={14} /> Schema Content
          </span>
          {doctext && (
            <button onClick={handleCopy} className={`schema__copy-button${copied ? ' schema__copy-button--copied' : ''}`}>
              {copied ? <FaCheck size={12} /> : <FaCopy size={12} />}
              {copied ? 'Copied!' : 'Copy'}
            </button>
          )}
        </div>

        {doctext ? (
          <div className="schema__code-container">
            <table className="schema__code-table">
              <tbody>
                {lines.map((line, idx) => (
                  <tr key={idx}>
                    <td className="schema__line-number">{idx + 1}</td>
                    <td className="schema__code-line">{line || ' '}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="schema__empty-state">
            No schema content defined.
          </div>
        )}
      </div>

      {/* Developer Source Map */}
      {!!isDeveloper && sourceMap && (
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
