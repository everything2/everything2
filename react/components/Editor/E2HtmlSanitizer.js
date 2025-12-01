/**
 * E2 HTML Sanitizer and Link Parser
 *
 * Uses DOMPurify for secure HTML sanitization configured to match E2's
 * server-side "approved html tags" setting. This enables fully client-side
 * preview rendering without server round-trips.
 *
 * Features:
 * - Sanitizes HTML to only allow E2-approved tags and attributes
 * - Parses E2 [link] syntax into clickable links
 * - Reports unsupported tags/attributes for user feedback
 * - Works offline and is much faster than server rendering
 */

import DOMPurify from 'dompurify'

// E2's approved HTML tags and their allowed attributes
// Derived from the 'approved html tags' setting in the database
export const APPROVED_TAGS = {
  // Text formatting
  b: [],
  strong: [],
  i: [],
  em: [],
  u: [],
  s: [],
  strike: [],
  del: [],
  ins: [],
  big: [],
  small: [],
  sub: [],
  sup: [],
  tt: [],
  kbd: [],
  code: [],
  samp: [],
  var: [],
  cite: [],
  q: ['cite'],

  // Block elements
  p: ['align'],
  br: [],
  hr: ['width'],
  pre: [],
  blockquote: ['cite'],
  center: [],

  // Headings
  h1: ['align'],
  h2: ['align'],
  h3: ['align'],
  h4: ['align'],
  h5: ['align'],
  h6: ['align'],

  // Lists
  ul: ['type'],
  ol: ['type', 'start'],
  li: [],
  dl: [],
  dt: [],
  dd: [],

  // Tables
  table: ['cellpadding', 'border', 'cellspacing', 'cols', 'frame', 'width'],
  caption: [],
  thead: [],
  tbody: [],
  tr: ['align', 'valign'],
  th: ['rowspan', 'colspan', 'align', 'valign', 'height', 'width'],
  td: ['rowspan', 'colspan', 'align', 'valign', 'height', 'width'],

  // Semantic
  abbr: ['lang', 'title'],
  acronym: ['lang', 'title'],
}

// Build DOMPurify configuration from APPROVED_TAGS
const ALLOWED_TAGS = Object.keys(APPROVED_TAGS)
const ALLOWED_ATTR = [...new Set(Object.values(APPROVED_TAGS).flat())]

// DOMPurify configuration for E2 content
const DOMPURIFY_CONFIG = {
  ALLOWED_TAGS,
  ALLOWED_ATTR,
  ALLOW_DATA_ATTR: false,
  ALLOW_UNKNOWN_PROTOCOLS: false,
  RETURN_DOM: false,
  RETURN_DOM_FRAGMENT: false,
  RETURN_TRUSTED_TYPE: false,
  WHOLE_DOCUMENT: false,
  SANITIZE_DOM: true,
}

/**
 * Parse E2 [link] syntax into HTML anchor tags
 *
 * Supports:
 * - [nodename] -> link to node with nodename as display text
 * - [nodename|display text] -> link to node with custom display text
 *
 * @param {string} text - Text containing E2 link syntax
 * @returns {string} - Text with links converted to anchor tags
 */
export function parseE2Links(text) {
  if (!text) return ''

  // Match [content] but handle [title|display] format
  // Don't match empty brackets or brackets with only whitespace
  return text.replace(
    /\[([^\[\]|]+)(?:\|([^\[\]]+))?\]/g,
    (match, title, displayText) => {
      const trimmedTitle = title.trim()
      if (!trimmedTitle) return match // Don't convert empty links

      const display = (displayText || title).trim()
      const encodedTitle = encodeURIComponent(trimmedTitle)
      // Use /title/ URL format which is the standard E2 link format
      return `<a href="/title/${encodedTitle}" class="e2-link">${escapeHtml(display)}</a>`
    }
  )
}

/**
 * Escape HTML entities in text
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
 * Sanitize HTML using DOMPurify with E2's approved tags configuration
 *
 * @param {string} html - Raw HTML to sanitize
 * @param {Object} options - Options
 * @param {boolean} options.parseLinks - Whether to parse [link] syntax (default: true)
 * @param {boolean} options.reportIssues - Whether to track removed elements (default: false)
 * @returns {Object} - { html: sanitizedHtml, issues: [{type, tag, attr}] }
 */
export function sanitizeHtml(html, options = {}) {
  const { parseLinks = true, reportIssues = false } = options
  const issues = []

  if (!html) {
    return { html: '', issues }
  }

  // Set up hooks to track removed elements if requested
  if (reportIssues) {
    DOMPurify.addHook('uponSanitizeElement', (node, data) => {
      if (data.tagName && !ALLOWED_TAGS.includes(data.tagName)) {
        issues.push({
          type: 'unsupported_tag',
          tag: data.tagName,
        })
      }
    })

    DOMPurify.addHook('uponSanitizeAttribute', (node, data) => {
      const tagName = node.tagName?.toLowerCase()
      if (data.attrName && tagName) {
        const allowedForTag = APPROVED_TAGS[tagName] || []
        if (!allowedForTag.includes(data.attrName) && data.attrName !== 'class') {
          issues.push({
            type: 'unsupported_attribute',
            tag: tagName,
            attr: data.attrName,
          })
        }
      }
    })
  }

  // Sanitize the HTML
  let sanitized = DOMPurify.sanitize(html, DOMPURIFY_CONFIG)

  // Clean up hooks
  if (reportIssues) {
    DOMPurify.removeAllHooks()
  }

  // Parse E2 links if requested
  if (parseLinks) {
    sanitized = parseE2Links(sanitized)
  }

  return { html: sanitized, issues }
}

/**
 * Render E2 content for preview display
 *
 * This is the main function to use for client-side preview rendering.
 * It sanitizes HTML and parses E2 links in one pass.
 *
 * @param {string} html - HTML content with possible E2 [link] syntax
 * @param {Object} options - Options to pass to sanitizeHtml
 * @returns {Object} - { html: renderedHtml, issues: [...] }
 */
export function renderE2Content(html, options = {}) {
  return sanitizeHtml(html, { parseLinks: true, ...options })
}

/**
 * Check if HTML content uses any unsupported tags or attributes
 *
 * Useful for showing users what won't render correctly.
 *
 * @param {string} html - HTML to check
 * @returns {Object[]} - Array of issues found
 */
export function checkHtmlCompatibility(html) {
  const { issues } = sanitizeHtml(html, { parseLinks: false, reportIssues: true })
  return issues
}

/**
 * Get a human-readable summary of compatibility issues
 *
 * @param {Object[]} issues - Issues from checkHtmlCompatibility
 * @returns {string} - Human-readable summary
 */
export function formatCompatibilityReport(issues) {
  if (!issues || issues.length === 0) {
    return 'All HTML tags and attributes are supported.'
  }

  const tagIssues = issues.filter(i => i.type === 'unsupported_tag')
  const attrIssues = issues.filter(i => i.type === 'unsupported_attribute')

  const parts = []

  if (tagIssues.length > 0) {
    const uniqueTags = [...new Set(tagIssues.map(i => i.tag))]
    parts.push(`Unsupported tags: ${uniqueTags.map(t => `<${t}>`).join(', ')}`)
  }

  if (attrIssues.length > 0) {
    const uniqueAttrs = [...new Set(attrIssues.map(i => `${i.tag}[${i.attr}]`))]
    parts.push(`Unsupported attributes: ${uniqueAttrs.join(', ')}`)
  }

  return parts.join('\n')
}

export default {
  APPROVED_TAGS,
  ALLOWED_TAGS,
  ALLOWED_ATTR,
  parseE2Links,
  sanitizeHtml,
  renderE2Content,
  checkHtmlCompatibility,
  formatCompatibilityReport,
  escapeHtml,
}
