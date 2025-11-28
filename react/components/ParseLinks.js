import React from 'react'
import LinkNode from './LinkNode'

/**
 * ParseLinks - Parses E2 link syntax and converts to React components
 *
 * Handles E2's bracket link syntax:
 * - [http://url] or [https://url] - external links
 * - [http://url|display text] - external links with custom text
 * - [http://url|] - external links with "[link]" as text
 * - [node title] - internal E2 node links
 * - [title|display] - internal pipelinks with custom display text
 * - [title[nodetype]] - internal links with explicit nodetype (e.g., [root[user]])
 * - [title[writeup by author]] - link to specific author's writeup
 * - [title[123]] - link to discussion comment (numeric ID)
 *
 * This is the React equivalent of the Perl parseLinks() function.
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
  const parts = []
  let lastIndex = 0
  let key = 0

  // Pattern for external links: [http://url] or [http://url|text] or [http://url|]
  const externalLinkPattern = /\[\s*(https?:\/\/[^\]|[\]<>"]+)(?:\|\s*([^\]|[\]]*)?)?\]/g

  // Pattern for internal links: matches the Perl pattern exactly
  // [^[\]]* - any text not containing brackets (title)
  // (?:\[[^\]|]*[\]|][^[\]]*)? - optionally: '[' + nodetype + ']' or '|' + more text
  // This handles: [title], [title|display], and [title[nodetype]]
  const internalLinkPattern = /\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)\]/g

  // First pass: Find all external links
  const externalLinks = []
  let match
  while ((match = externalLinkPattern.exec(textString)) !== null) {
    const url = match[1]
    let display = match[2]

    // If pipe exists but display is empty, use "[link]"
    if (match[0].includes('|') && (!display || display.trim() === '')) {
      display = '[link]'
    } else if (!display) {
      display = url
    }

    externalLinks.push({
      start: match.index,
      end: match.index + match[0].length,
      url,
      display,
      type: 'external'
    })
  }

  // Second pass: Find all internal links (avoiding external link positions)
  internalLinkPattern.lastIndex = 0
  const internalLinks = []
  while ((match = internalLinkPattern.exec(textString)) !== null) {
    const start = match.index
    const end = match.index + match[0].length

    // Check if this overlaps with an external link
    const overlaps = externalLinks.some(ext =>
      (start >= ext.start && start < ext.end) ||
      (end > ext.start && end <= ext.end)
    )

    if (!overlaps) {
      const content = match[1]
      let title, display, nodetype, author, anchor, params

      // Check for nested bracket syntax: [title[nodetype]] or [display|title[nodetype]]
      // First check if there's a pipe AND nested brackets: [display|title[nodetype]]
      const pipeAndBracketMatch = content.match(/^([^|[\]]+)\|([^[\]]+)\[([^\]|]+)\]$/)
      if (pipeAndBracketMatch) {
        // [display|title[nodetype]]
        display = pipeAndBracketMatch[1].trim()
        title = pipeAndBracketMatch[2].trim()
        const typeSpec = pipeAndBracketMatch[3].trim()

        // Check for "by" syntax: [title[writeup by author]]
        if (typeSpec.includes(' by ')) {
          const [type, auth] = typeSpec.split(/\s+by\s+/)
          nodetype = type.trim()
          author = auth.trim()
        } else if (/^\d+$/.test(typeSpec)) {
          // Numeric nodetype is a comment ID
          anchor = `debatecomment_${typeSpec}`
          title = title // Keep title for debate URL
        } else {
          nodetype = typeSpec
        }
      } else {
        // Check for nested bracket syntax without pipe: [title[nodetype]]
        const nestedMatch = content.match(/^([^[\]|]+)\[([^\]|]+)\]$/)
        if (nestedMatch) {
          // Nested bracket syntax: [title[nodetype]]
          title = nestedMatch[1].trim()
          display = title
          const typeSpec = nestedMatch[2].trim()

          // Check for "by" syntax: [title[writeup by author]]
          if (typeSpec.includes(' by ')) {
            const [type, auth] = typeSpec.split(/\s+by\s+/)
            nodetype = type.trim() || 'writeup'
            author = auth.trim()

            // For writeup by author, we need author_id param and anchor
            // LinkNode will handle this with the author prop
          } else if (/^\d+$/.test(typeSpec)) {
            // Numeric nodetype is a comment ID
            anchor = `debatecomment_${typeSpec}`
            // Don't set nodetype, let it default to /node/debate/title
          } else {
            nodetype = typeSpec
          }
        } else if (content.includes('|')) {
          // Pipe syntax: [title|display]
          // In E2, format is [title|display] where title is the target, display is shown
          const pipeParts = content.split('|')
          title = pipeParts[0].trim()
          display = pipeParts[1].trim()
        } else {
          // Simple syntax: [title]
          title = content.trim()
          display = title
        }
      }

      internalLinks.push({
        start,
        end,
        title,
        display,
        nodetype,
        author,
        anchor,
        params,
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
      parts.push(textString.substring(lastIndex, link.start))
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
          style={{ fontSize: 'inherit' }}
        >
          {link.display}
        </a>
      )
    } else {
      // For internal links, pass all the props LinkNode needs
      const linkKey = `link-${key++}`
      const linkProps = {
        title: link.title,
        display: link.display
      }

      if (link.nodetype) linkProps.type = link.nodetype
      if (link.author) linkProps.author = link.author
      if (link.anchor) linkProps.anchor = link.anchor
      if (link.params) linkProps.params = link.params

      parts.push(<LinkNode key={linkKey} {...linkProps} />)
    }

    lastIndex = link.end
  })

  // Add any remaining plain text
  if (lastIndex < textString.length) {
    parts.push(textString.substring(lastIndex))
  }

  return <>{parts}</>
}

export default ParseLinks
