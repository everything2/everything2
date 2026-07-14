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
 * The inline (phrasing-content) tags allowed inside a pipelink's DISPLAY text.
 * This is the inline subset of E2HtmlSanitizer's APPROVED_TAGS — kept in sync by
 * hand rather than a 4th independent list (#4534/#4394). Deliberately excludes
 * `a` (nested anchors break the outer link) and every block tag (invalid nesting
 * inside an inline <a>).
 */
export const INLINE_DISPLAY_TAGS = new Set([
  'abbr', 'acronym', 'b', 'strong', 'i', 'em', 'u', 's', 'strike', 'del', 'ins',
  'big', 'small', 'sub', 'sup', 'tt', 'kbd', 'code', 'samp', 'var', 'cite', 'q', 'br'
])

/**
 * Keep only the inline-allowlist tags in a display string, unwrapping everything
 * else (dropping the tag markup but keeping its text content).
 *
 * SECURITY CONTRACT: this is NOT a security sanitizer. Its only caller,
 * parseLinksToHtml, runs exclusively downstream of E2HtmlSanitizer's DOMPurify
 * pass, which has already removed <script>/<iframe>/javascript: URLs and every
 * disallowed attribute. This function only enforces inline-only nesting inside
 * <a> (dropping block tags + nested <a>). As cheap defense-in-depth against a
 * future caller that skips DOMPurify, event-handler (on*) attributes are also
 * stripped from the tags we keep.
 *
 * @param {string} str - Display string, already DOMPurify-sanitized
 * @returns {string} - Display with only inline tags preserved
 */
export function keepInlineHtml(str) {
  if (!str) return ''
  return str.replace(/<(\/?)\s*([a-zA-Z0-9]+)((?:[^>"']|"[^"]*"|'[^']*')*)>/g, (full, slash, name, attrs) => {
    const tag = name.toLowerCase()
    if (!INLINE_DISPLAY_TAGS.has(tag)) return ''   // unwrap non-inline tag, keep its text
    if (slash) return `</${tag}>`
    // Drop any on*-handler attributes belt-and-suspenders; keep the rest (already
    // DOMPurify-vetted for these tags — e.g. title/lang on abbr, cite on q).
    const safeAttrs = attrs.replace(/\s+on[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    return `<${tag}${safeAttrs}>`
  })
}

/**
 * Build a link's display fields from a raw (possibly-HTML) display string.
 * Returns `{ display }` (plain text, for the escaped React/LinkNode path) and,
 * only when the raw display actually contained preserved inline markup, an extra
 * `displayHtml` (for parseLinksToHtml, which emits it un-escaped downstream of
 * DOMPurify — see keepInlineHtml). Omitting displayHtml when there's no HTML
 * keeps segment objects clean and the string path on its plain-text default.
 *
 * @param {string|undefined|null} rawDisplay - the matched display group
 * @param {string} fallbackTitle - display to use when rawDisplay is empty
 * @returns {Object} - { display } or { display, displayHtml }
 */
export function displayFields(rawDisplay, fallbackTitle) {
  const plain = rawDisplay != null ? stripHtml(rawDisplay).trim() : ''
  const html = rawDisplay != null ? keepInlineHtml(rawDisplay).trim() : ''
  const display = plain || fallbackTitle
  return (html && html !== plain) ? { display, displayHtml: html } : { display }
}

/**
 * Decode common HTML entities back to their literal characters. Required
 * inside link bracket content because DOMPurify entity-encodes characters
 * like '&' before parseLinks runs over the sanitized HTML — without this,
 * a node title like "Sense & Sensibility" would reach the link builder as
 * "Sense &amp; Sensibility", producing a dead URL and a display string
 * containing the literal text "&amp" (#4060).
 *
 * Bracket entities (&#91; / &#93;) are NOT decoded here; they're handled
 * separately via placeholders in sanitizeHtml so users can still escape
 * literal brackets in writeups without triggering link parsing.
 *
 * @param {string} text - Text possibly containing HTML entities
 * @returns {string} - Text with common entities decoded
 */
export function decodeHtmlEntities(text) {
  if (!text) return ''
  return text
    // &amp; must run first — otherwise &amp;lt; would decode to &lt; → < (wrong)
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
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

  // Decode HTML entities first — DOMPurify ran upstream and entity-encoded
  // characters like '&' for HTML safety, but the title/display text inside
  // brackets needs to be the literal character so the URL builder and the
  // visible display text are correct (#4060).
  const trimmedContent = decodeHtmlEntities(content).trim()
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

    if (title && author) {
      return {
        type: LINK_TYPE.USER_WRITEUP,
        title,
        author,
        ...displayFields(byAuthorMatch[3], title),
        href: `/user/${encodeURIComponent(author)}/writeups/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [title[nodetype]] / [title[nodetype]|display] / [title[123]] syntax
  // (typed link or comment). The optional trailing `|display` covers the
  // bracket-before-pipe ordering (e.g. [gate[user]|gate's]) — without it that
  // form fell through to the plain pipe-split below, which left "gate[user]" as
  // the title and produced a dead /title/gate[user] link (#4532). This mirrors
  // the optional-pipe the [title[by author]] branch above already has.
  const typedMatch = trimmedContent.match(/^([^\[\]|]+?)\s*\[\s*([^\[\]]+?)\s*\](?:\s*\|\s*(.*))?$/)
  if (typedMatch) {
    const title = stripHtml(typedMatch[1]).trim()
    const typeSpec = stripHtml(typedMatch[2]).trim()
    const display = displayFields(typedMatch[3], title)

    if (title && typeSpec) {
      // Check if typeSpec is a numeric comment ID
      if (/^\d+$/.test(typeSpec)) {
        return {
          type: LINK_TYPE.COMMENT,
          title,
          commentId: typeSpec,
          ...display,
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
        ...display,
        href: `/${nodetype}/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [display|title[nodetype]] syntax (pipelink with type)
  const pipeAndBracketMatch = trimmedContent.match(/^([^|[\]]+)\|([^[\]]+)\[([^\]|]+)\]$/)
  if (pipeAndBracketMatch) {
    const df = displayFields(pipeAndBracketMatch[1], '')
    const display = df.display
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
            ...df,
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
          ...df,
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
        ...df,
        href: `/${nodetype}/${encodeURIComponent(title)}`
      }
    }
  }

  // Check for [title|display] syntax (standard pipelink)
  if (trimmedContent.includes('|')) {
    const parts = trimmedContent.split('|')
    const title = stripHtml(parts[0]).trim()

    if (title) {
      return {
        type: LINK_TYPE.INTERNAL,
        title,
        ...displayFields(parts[1], title),
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

    // It's a link. Prefer displayHtml (a sanitized inline subset preserved from
    // the pipelink display, e.g. <abbr title="…">) when present — it's emitted
    // un-escaped because it's already DOMPurify-vetted upstream (#4534). Otherwise
    // fall back to the escaped plain-text display.
    const renderedDisplay = segment.displayHtml != null ? segment.displayHtml : escapeHtml(segment.display)

    if (segment.type === LINK_TYPE.EXTERNAL) {
      // External link - show URL in hover
      const escapedUrl = escapeHtml(segment.href)
      return `<a href="${segment.href}" rel="nofollow" class="externalLink" target="_blank" title="${escapedUrl}">${renderedDisplay}</a>`
    }

    // Internal links
    let href = segment.href
    if (segment.anchor) {
      href += `#${segment.anchor}`
    }

    // Show the link target in hover (useful for pipelinks where display differs from target)
    const escapedTitle = escapeHtml(segment.title)
    return `<a href="${href}" class="e2-link" title="${escapedTitle}">${renderedDisplay}</a>`
  }).join('')
}

export default {
  LINK_TYPE,
  INLINE_DISPLAY_TAGS,
  escapeHtml,
  stripHtml,
  keepInlineHtml,
  displayFields,
  parseLinkContent,
  parseLinks,
  parseLinksToHtml
}
