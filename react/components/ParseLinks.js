import React from 'react'
import LinkNode from './LinkNode'

/**
 * ParseLinks - Parses E2 link syntax and converts to React components
 *
 * Handles E2's bracket link syntax:
 * - [http://url] or [https://url] - external links
 * - [http://url|display text] - external links with custom text
 * - [node title] - internal E2 node links
 * - [node title|display text] - internal links with custom text
 * - [title[nodetype]] - internal links with explicit nodetype (e.g., [root[user]])
 *
 * This is the React equivalent of the Perl parseLinks() function.
 */
const ParseLinks = ({ children }) => {
  if (!children) return null

  const text = String(children)
  const parts = []
  let lastIndex = 0
  let key = 0

  // Pattern for external links: [http://url] or [http://url|text]
  const externalLinkPattern = /\[\s*(https?:\/\/[^\]|[\]<>"]+)(?:\|\s*([^\]|[\]]+))?\]/g

  // Pattern for internal links: matches the Perl pattern exactly
  // [^[\]]* - any text not containing brackets (title)
  // (?:\[[^\]|]*[\]|][^[\]]*)? - optionally: '[' + nodetype + ']' or '|' + more text
  // This handles: [title], [title|display], and [title[nodetype]]
  const internalLinkPattern = /\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)\]/g

  // First pass: Find all external links
  const externalLinks = []
  let match
  while ((match = externalLinkPattern.exec(text)) !== null) {
    externalLinks.push({
      start: match.index,
      end: match.index + match[0].length,
      url: match[1],
      display: match[2] || match[1],
      type: 'external'
    })
  }

  // Second pass: Find all internal links (avoiding external link positions)
  internalLinkPattern.lastIndex = 0
  const internalLinks = []
  while ((match = internalLinkPattern.exec(text)) !== null) {
    const start = match.index
    const end = match.index + match[0].length

    // Check if this overlaps with an external link
    const overlaps = externalLinks.some(ext =>
      (start >= ext.start && start < ext.end) ||
      (end > ext.start && end <= ext.end)
    )

    if (!overlaps) {
      const content = match[1]
      let title, display, nodetype

      // Check for nested bracket syntax: [title[nodetype]]
      const nestedMatch = content.match(/^([^[\]|]+)\[([^\]|]+)\]$/)
      if (nestedMatch) {
        // Nested bracket syntax: [title[nodetype]]
        title = nestedMatch[1].trim()
        nodetype = nestedMatch[2].trim()
        display = title
      } else if (content.includes('|')) {
        // Pipe syntax: [title|display]
        const parts = content.split('|')
        title = parts[0].trim()
        display = parts[1].trim()
      } else {
        // Simple syntax: [title]
        title = content.trim()
        display = title
      }

      internalLinks.push({
        start,
        end,
        title,
        display,
        nodetype,
        type: 'internal'
      })
    }
  }

  // Combine and sort all links by position
  const allLinks = [...externalLinks, ...internalLinks].sort((a, b) => a.start - b.start)

  // Build the output with links and plain text
  allLinks.forEach(link => {
    // Add any plain text before this link
    if (link.start > lastIndex) {
      parts.push(text.substring(lastIndex, link.start))
    }

    // Add the link
    if (link.type === 'external') {
      parts.push(
        <a
          key={`link-${key++}`}
          href={link.url}
          rel="nofollow"
          className="externalLink"
          target="_blank"
        >
          {link.display}
        </a>
      )
    } else {
      parts.push(
        <LinkNode
          key={`link-${key++}`}
          title={link.title}
          type={link.nodetype}
        />
      )
    }

    lastIndex = link.end
  })

  // Add any remaining plain text
  if (lastIndex < text.length) {
    parts.push(text.substring(lastIndex))
  }

  return <>{parts}</>
}

export default ParseLinks
