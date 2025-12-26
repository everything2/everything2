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
import { parseLinksToHtml, escapeHtml as sharedEscapeHtml } from '../../utils/linkParser'

// E2's approved HTML tags and their allowed attributes
// Derived from the 'approved html tags' setting in the database
// NOTE: h1 is intentionally excluded - user-submitted h1s are converted to h2
// to maintain proper heading hierarchy (page title is the only h1)
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

  // Headings (h1 excluded - converted to h2 for SEO hierarchy)
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
// Include 'class' for user-h1 styling on converted h1→h2
const ALLOWED_ATTR = [...new Set([...Object.values(APPROVED_TAGS).flat(), 'class'])]

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
 * Uses the shared linkParser utility for consistent behavior across the codebase.
 * See react/utils/linkParser.js for full documentation of supported syntax.
 *
 * @param {string} text - Text containing E2 link syntax
 * @returns {string} - Text with links converted to anchor tags
 */
export function parseE2Links(text) {
  return parseLinksToHtml(text)
}

/**
 * Escape HTML entities in text
 * Re-exported from shared linkParser utility for backwards compatibility
 */
export function escapeHtml(text) {
  return sharedEscapeHtml(text)
}

/**
 * Convert plain text newlines to HTML paragraphs and line breaks
 *
 * This replicates the Perl breakTags() function from Application.pm.
 * It only activates for content that doesn't already have <p> or <br> tags,
 * which indicates legacy plain-text writeups.
 *
 * Logic:
 * 1. Skip if content already has <p> or <br> tags (already formatted)
 * 2. Protect newlines inside pre, ol, ul, dl, table tags
 * 3. Convert single newlines to <br>
 * 4. Convert double newlines / double <br> to paragraph breaks
 * 5. Wrap everything in <p> tags
 * 6. Clean up paragraph tags around block elements
 *
 * @param {string} text - Text that may contain plain newlines
 * @returns {string} - Text with newlines converted to HTML
 */
export function breakTags(text) {
  if (!text) return ''

  // If the content already has <p> or <br> tags, it's already formatted
  // Skip the conversion to avoid double-formatting
  if (/<\/?p[ >]/i.test(text) || /<br/i.test(text)) {
    return text
  }

  // Tags where we should NOT convert newlines (preserve as placeholders)
  const ignoreTags = ['pre', 'ol', 'ul', 'dl', 'table']
  const placeholder = '<!-- e2-newline-placeholder -->'

  let result = text

  // Replace newlines inside protected elements with placeholders
  for (const tag of ignoreTags) {
    // Match tag with optional attributes and preserve newlines inside
    const regex = new RegExp(`(<${tag}[^>]*>)([\\s\\S]*?)(<\\/${tag}>)`, 'gi')
    result = result.replace(regex, (match, openTag, content, closeTag) => {
      const protectedContent = content.replace(/\n/g, placeholder)
      return openTag + protectedContent + closeTag
    })
  }

  // Trim leading/trailing whitespace
  result = result.replace(/^\s+/, '').replace(/\s+$/, '')

  // Replace remaining newlines with <br>
  result = result.replace(/\n/g, '<br>')

  // Convert <br><br> sequences to paragraph breaks
  result = result.replace(/\s*<br>\s*<br>/g, '</p>\n\n<p>')

  // Wrap in paragraph tags
  result = '<p>' + result + '</p>'

  // Clean up paragraph tags around block elements
  // Don't wrap block elements inside paragraphs
  const blockTags = 'pre|center|li|ol|ul|h1|h2|h3|h4|h5|h6|blockquote|dd|dt|dl|p|table|td|tr|th|tbody|thead'
  const openBlockRegex = new RegExp(`<p><(${blockTags})`, 'gi')
  const closeBlockRegex = new RegExp(`</(${blockTags})></p>`, 'gi')
  result = result.replace(openBlockRegex, '<$1')
  result = result.replace(closeBlockRegex, '</$1>')

  // Restore protected newlines
  result = result.replace(new RegExp(placeholder, 'g'), '\n')

  return result
}

/**
 * Convert h1 tags to h2 for proper heading hierarchy
 * The page title is the only h1, so user-submitted h1s become h2s
 * Adds class="user-h1" so they can be styled larger than regular h2s
 *
 * @param {string} html - HTML string
 * @returns {string} - HTML with h1 converted to h2.user-h1
 */
function convertH1ToH2(html) {
  if (!html) return html
  // Replace opening h1 tags with h2 + user-h1 class for styling
  // Handles <h1>, <h1 align="center">, </h1>, etc.
  return html
    .replace(/<h1>/gi, '<h2 class="user-h1">')
    .replace(/<h1\s+/gi, '<h2 class="user-h1" ')
    .replace(/<\/h1>/gi, '</h2>')
}

// Placeholders for raw bracket entities during sanitization
// These must not appear in normal content and survive DOMPurify
const RAW_LEFT_BRACKET_PLACEHOLDER = '\uE000E2RAWLBRACKET\uE001'
const RAW_RIGHT_BRACKET_PLACEHOLDER = '\uE000E2RAWRBRACKET\uE001'

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

  // Convert h1 to h2 for proper heading hierarchy (page title is the only h1)
  let processedHtml = convertH1ToH2(html)

  // Protect raw bracket entities from being decoded by DOMPurify
  // &#91; and &#93; are used for literal brackets that shouldn't become E2 links
  // DOMPurify decodes entities when parsing HTML, so we replace them with placeholders
  processedHtml = processedHtml
    .replace(/&#91;/g, RAW_LEFT_BRACKET_PLACEHOLDER)
    .replace(/&#93;/g, RAW_RIGHT_BRACKET_PLACEHOLDER)

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
  let sanitized = DOMPurify.sanitize(processedHtml, DOMPURIFY_CONFIG)

  // Clean up hooks
  if (reportIssues) {
    DOMPurify.removeAllHooks()
  }

  // Parse E2 links if requested
  if (parseLinks) {
    sanitized = parseE2Links(sanitized)
  }

  // Restore raw bracket entities after link parsing
  // These should now render as literal [ and ] characters
  sanitized = sanitized
    .replace(new RegExp(RAW_LEFT_BRACKET_PLACEHOLDER, 'g'), '[')
    .replace(new RegExp(RAW_RIGHT_BRACKET_PLACEHOLDER, 'g'), ']')

  return { html: sanitized, issues }
}

/**
 * Render E2 content for preview display
 *
 * This is the main function to use for client-side preview rendering.
 * It applies breakTags (newline->paragraph conversion), sanitizes HTML,
 * and parses E2 links.
 *
 * @param {string} html - HTML content with possible E2 [link] syntax
 * @param {Object} options - Options to pass to sanitizeHtml
 * @param {boolean} options.applyBreakTags - Whether to apply breakTags conversion (default: true)
 * @returns {Object} - { html: renderedHtml, issues: [...] }
 */
export function renderE2Content(html, options = {}) {
  const { applyBreakTags = true, ...sanitizeOptions } = options

  // First, apply breakTags to convert plain-text newlines to HTML
  // This handles legacy writeups that were written without HTML formatting
  let processedHtml = html
  if (applyBreakTags) {
    processedHtml = breakTags(html)
  }

  return sanitizeHtml(processedHtml, { parseLinks: true, ...sanitizeOptions })
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
  breakTags,
}
