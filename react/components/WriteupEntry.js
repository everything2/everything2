import React from 'react'
import LinkNode from './LinkNode'
import EditorHideWriteup from './EditorHideWriteup'
import { FaEye, FaEyeSlash } from 'react-icons/fa'
import { IconContext } from 'react-icons'

/**
 * Unified Writeup/Node Entry Component
 *
 * Provides consistent display formatting across multiple nodelets:
 * - NewWriteups
 * - NewLogs
 * - UsergroupWriteups
 * - RecentNodes
 * - NeglectedDrafts
 *
 * Display modes:
 * - 'full': Title, parent, type, author, metadata (NewWriteups, NewLogs)
 * - 'standard': Title, author, metadata (NeglectedDrafts)
 * - 'simple': Title only (UsergroupWriteups, RecentNodes)
 */
const WriteupEntry = ({
  // Entry data
  entry,

  // Display mode: 'full' | 'standard' | 'simple'
  mode = 'full',

  // Optional overrides
  showParent = null,
  showAuthor = null,
  showType = null,
  showMetadata = null,

  // Editor features
  editor = false,
  editorHideWriteupChange = null,

  // Additional metadata
  metadata = null, // Custom metadata string/element (e.g., "[3 days]")

  // CSS classes
  className = 'contentinfo',

  // Custom rendering
  customContent = null
}) => {
  // Determine what to show based on mode
  const shouldShowParent = showParent ?? (mode === 'full')
  const shouldShowAuthor = showAuthor ?? (mode !== 'simple')
  const shouldShowType = showType ?? (mode === 'full')
  const shouldShowMetadata = showMetadata ?? (metadata !== null)

  // Extract data from entry
  const nodeId = entry.node_id
  const title = entry.title || '(untitled)'
  const parent = entry.parent
  const author = entry.author
  const writeuptype = entry.writeuptype
  const hasvoted = entry.hasvoted

  // Build link parameters
  let linkparams = {}
  let authoranchor = null

  if (author && author.node_id) {
    authoranchor = author.title
    linkparams = { author_id: author.node_id }
  }

  // Build CSS classes
  let cssClasses = className
  if (hasvoted) {
    cssClasses += ' hasvoted'
  }

  return (
    <IconContext.Provider value={{ style: { lineHeight: 'inherit!important', verticalAlign: 'middle' } }}>
      <li className={cssClasses}>
        {/* Main title link */}
        {shouldShowParent && parent ? (
          // Show parent e2node title (for writeups)
          <LinkNode
            title={parent.title || title}
            className="title"
            params={linkparams}
            anchor={authoranchor}
          />
        ) : (
          // Show node title directly
          <LinkNode
            nodeId={nodeId}
            title={title}
            className="title"
          />
        )}

        {/* Writeup type */}
        {shouldShowType && writeuptype && parent && (
          <span className="type">
            (
            <LinkNode
              type="writeup"
              author={authoranchor}
              display={writeuptype}
              title={parent.title}
            />
            )
          </span>
        )}

        {/* Author byline */}
        {shouldShowAuthor && author && (
          <cite>
            {' by '}
            <LinkNode
              type="user"
              title={author.title}
              className="author"
            />
          </cite>
        )}

        {/* Custom metadata */}
        {shouldShowMetadata && metadata && (
          <span className="metadata">{metadata}</span>
        )}

        {/* Custom content (for special cases) */}
        {customContent}

        {/* Editor controls */}
        {editor && editorHideWriteupChange && (
          <EditorHideWriteup entry={entry} editorHideWriteupChange={editorHideWriteupChange} />
        )}
      </li>
    </IconContext.Provider>
  )
}

export default WriteupEntry
