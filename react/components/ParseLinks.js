import React from 'react'
import LinkNode from './LinkNode'
import { parseLinks, LINK_TYPE } from '../utils/linkParser'

/**
 * ParseLinks - Parses E2 link syntax and converts to React components
 *
 * Uses the shared linkParser utility for consistent behavior across the codebase.
 * See react/utils/linkParser.js for full documentation of supported syntax.
 *
 * Supports:
 * - [http://url] or [https://url] - external links
 * - [http://url|display text] - external links with custom text
 * - [http://url|] - external links with "[link]" as text
 * - [node title] - internal E2 node links
 * - [title|display] - internal pipelinks with custom display text
 * - [title[nodetype]] - internal links with explicit nodetype (e.g., [root[user]])
 * - [title[writeup by author]] - link to specific author's writeup
 * - [title[123]] - link to discussion comment (numeric ID)
 *
 * Usage:
 *   <ParseLinks text="some [link] text" />
 *   or
 *   <ParseLinks>some [link] text</ParseLinks>
 */
const ParseLinks = ({ text, children }) => {
  // Accept either text prop or children
  const input = text || children
  if (!input) return null

  const textString = String(input)
  const segments = parseLinks(textString)

  let key = 0
  const parts = segments.map(segment => {
    if (segment.type === 'text') {
      return segment.content
    }

    // External link
    if (segment.type === LINK_TYPE.EXTERNAL) {
      return (
        <a
          key={`link-${key++}`}
          href={segment.href}
          rel="nofollow"
          className="externalLink"
          target="_blank"
          style={{ fontSize: 'inherit' }}
        >
          {segment.display}
        </a>
      )
    }

    // Internal links use LinkNode component
    const linkKey = `link-${key++}`
    const linkProps = {
      title: segment.title,
      display: segment.display
    }

    // Map link types to LinkNode props
    if (segment.type === LINK_TYPE.TYPED) {
      linkProps.type = segment.nodetype
    } else if (segment.type === LINK_TYPE.USER_WRITEUP) {
      linkProps.author = segment.author
    } else if (segment.type === LINK_TYPE.COMMENT) {
      linkProps.anchor = segment.anchor
    }

    return <LinkNode key={linkKey} {...linkProps} />
  })

  return <>{parts}</>
}

export default ParseLinks
