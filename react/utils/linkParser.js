/**
 * E2 Link Parser Utility
 *
 * Parses E2's bracket link syntax and returns structured link data.
 * This is the single source of truth for link parsing logic, used by both:
 * - ParseLinks.js (React component that renders links)
 * - E2HtmlSanitizer.js (HTML string generation for previews)
 *
 * Link syntax supported:
 * - [http://url] or [https://url] - external links
 * - [http://url|display text] - external links with custom text
 * - [http://url|] - external links with "[link]" as display text
 * - [node title] - internal E2 node links
 * - [title|display] - internal pipelinks with custom display text
 * - [title[nodetype]] - internal links with explicit nodetype (e.g., [root[user]])
 * - [title[writeup by author]] - link to specific author's writeup
 * - [title[123]] - link to discussion comment (numeric ID)
 */

/**
 * Escape HTML entities in text
 * @param {string} text - Text to escape
 * @returns {string} - Escaped text
 */
export function escapeHtml(text) {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

/**
 * Strip HTML tags from a string
 * @param {string} str - String possibly containing HTML
 * @returns {string} - String with HTML tags removed
 */
export function stripHtml(str) {
  if (!str) return ''
  return str.replace(/<[^>]*>/g, '')
}

/**
 * Link types returned by the parser
 */
export const LINK_TYPE = {
  EXTERNAL: 'external',
  INTERNAL: 'internal',
  USER_WRITEUP: 'user_writeup',
  TYPED: 'typed',
  COMMENT: 'comment'
}

/**
 * Parse a single link's content and return structured data
 *
 * @param {string} content - The content inside the brackets (without the brackets)
 * @param {string} fullMatch - The full matched string including brackets
 * @returns {Object|null} - Link data object or null if invalid
 */
export function parseLinkContent(content, fullMatch) {
  if (!content) return null

  const trimmedContent = content.trim()
  if (!trimmedContent) return null

  // Check for external URL
  const externalMatch = trimmedContent.match(/^\s*(https?:\/\/[^\|\[<>"]+)\s*(?:\|\s*(.*))?$/)
  if (externalMatch) {
    const url = externalMatch[1].trim()
    let display

    // Determine display text
    if (fullMatch.includes('|')) {
      // Pipe exists - use text after pipe, or "[link]" if empty
      display = externalMatch[2]?.trim() || '[link]'
    } else {
      // No pipe - use URL as display
      display = url
    }

    return {
      type: LINK_TYPE.EXTERNAL,
      url,
      display,
      href: url
    }
  }

  // Check for [title[by author]] syntax (writeup by specific author)
  const byAuthorMatch = trimmedContent.match(/^([^\[\]|]+?)\s*\[\s*by\s+(\S[^\[\]]*?)\s*\](?:\|([^\[\]]+))?$/i)
  if (byAuthorMatch) {
    const title = stripHtml(byAuthorMatch[1]).trim()
    const author = stripHtml(byAuthorMatch[2]).trim()
    // Strip HTML from display text as well
    const displayText = byAuthorMatch[3] ? stripHtml(byAuthorMatch[3]).trim() : null

    if (title && author) {
      return {
        type: LINK_TYPE.USER_WRITEUP,
        title,
        author,
        display: displayText || title,
        href: `/user/${encodeURIComponent(author)}/writeups/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [title[nodetype]] or [title[123]] syntax (typed link or comment)
  const typedMatch = trimmedContent.match(/^([^\[\]|]+?)\s*\[\s*([^\[\]]+?)\s*\]$/)
  if (typedMatch) {
    const title = stripHtml(typedMatch[1]).trim()
    const typeSpec = stripHtml(typedMatch[2]).trim()

    if (title && typeSpec) {
      // Check if typeSpec is a numeric comment ID
      if (/^\d+$/.test(typeSpec)) {
        return {
          type: LINK_TYPE.COMMENT,
          title,
          commentId: typeSpec,
          display: title,
          href: `/title/${encodeURIComponent(title)}`,
          anchor: `debatecomment_${typeSpec}`
        }
      }

      // Skip if this looks like a failed [title[by username]] pattern
      if (/^by\s*$/i.test(typeSpec)) {
        return null
      }

      // Regular typed link
      const nodetype = typeSpec.toLowerCase()
      return {
        type: LINK_TYPE.TYPED,
        title,
        nodetype,
        display: title,
        href: `/${nodetype}/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [display|title[nodetype]] syntax (pipelink with type)
  const pipeAndBracketMatch = trimmedContent.match(/^([^|[\]]+)\|([^[\]]+)\[([^\]|]+)\]$/)
  if (pipeAndBracketMatch) {
    const display = stripHtml(pipeAndBracketMatch[1]).trim()
    const title = stripHtml(pipeAndBracketMatch[2]).trim()
    const typeSpec = stripHtml(pipeAndBracketMatch[3]).trim()

    if (display && title && typeSpec) {
      // Check for "by" syntax
      if (typeSpec.toLowerCase().startsWith('by ')) {
        const author = typeSpec.substring(3).trim()
        if (author) {
          return {
            type: LINK_TYPE.USER_WRITEUP,
            title,
            author,
            display,
            href: `/user/${encodeURIComponent(author)}/writeups/${encodeURIComponent(title)}`
          }
        }
      }

      // Numeric is comment ID
      if (/^\d+$/.test(typeSpec)) {
        return {
          type: LINK_TYPE.COMMENT,
          title,
          commentId: typeSpec,
          display,
          href: `/title/${encodeURIComponent(title)}`,
          anchor: `debatecomment_${typeSpec}`
        }
      }

      // Regular typed link
      const nodetype = typeSpec.toLowerCase()
      return {
        type: LINK_TYPE.TYPED,
        title,
        nodetype,
        display,
        href: `/${nodetype}/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [title|display] syntax (standard pipelink)
  if (trimmedContent.includes('|')) {
    const parts = trimmedContent.split('|')
    const title = stripHtml(parts[0]).trim()
    const display = stripHtml(parts[1]).trim()

    if (title) {
      return {
        type: LINK_TYPE.INTERNAL,
        title,
        display: display || title,
        href: `/title/${encodeURIComponent(title)}`
      }
    }
  }

  // Simple [title] syntax
  const title = stripHtml(trimmedContent).trim()
  if (title) {
    return {
      type: LINK_TYPE.INTERNAL,
      title,
      display: title,
      href: `/title/${encodeURIComponent(title)}`
    }
  }

  return null
}

/**
 * Parse all links in a text string and return an array of segments
 *
 * Each segment is either:
 * - { type: 'text', content: 'plain text' }
 * - { type: 'link', ...linkData }
 *
 * @param {string} text - Text containing E2 link syntax
 * @returns {Array} - Array of text and link segments
 */
export function parseLinks(text) {
  if (!text) return []

  const segments = []
  let lastIndex = 0

  // Match all bracketed expressions
  // This pattern handles:
  // - Simple: [text]
  // - With pipe: [text|display]
  // - Nested: [text[type]]
  // - Complex: [text[type]|display] or [display|text[type]]
  const pattern = /\[([^\[\]]*(?:\[[^\]]*\][^\[\]]*)?)\]/g

  let match
  while ((match = pattern.exec(text)) !== null) {
    const fullMatch = match[0]
    const content = match[1]
    const start = match.index
    const end = start + fullMatch.length

    // Add any text before this match
    if (start > lastIndex) {
      segments.push({
        type: 'text',
        content: text.substring(lastIndex, start)
      })
    }

    // Parse the link content
    const linkData = parseLinkContent(content, fullMatch)

    if (linkData) {
      segments.push({
        ...linkData,
        raw: fullMatch
      })
    } else {
      // Not a valid link, keep as text
      segments.push({
        type: 'text',
        content: fullMatch
      })
    }

    lastIndex = end
  }

  // Add any remaining text
  if (lastIndex < text.length) {
    segments.push({
      type: 'text',
      content: text.substring(lastIndex)
    })
  }

  return segments
}

/**
 * Convert parsed links to HTML string
 *
 * @param {string} text - Text containing E2 link syntax
 * @returns {string} - HTML with links converted to anchor tags
 */
export function parseLinksToHtml(text) {
  if (!text) return ''

  const segments = parseLinks(text)

  return segments.map(segment => {
    if (segment.type === 'text') {
      return segment.content
    }

    // It's a link
    const escapedDisplay = escapeHtml(segment.display)

    if (segment.type === LINK_TYPE.EXTERNAL) {
      return `<a href="${segment.href}" rel="nofollow" class="externalLink" target="_blank">${escapedDisplay}</a>`
    }

    // Internal links
    let href = segment.href
    if (segment.anchor) {
      href += `#${segment.anchor}`
    }

    return `<a href="${href}" class="e2-link">${escapedDisplay}</a>`
  }).join('')
}

export default {
  LINK_TYPE,
  escapeHtml,
  stripHtml,
  parseLinkContent,
  parseLinks,
  parseLinksToHtml
}
