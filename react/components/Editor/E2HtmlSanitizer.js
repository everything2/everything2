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

// Block-level tags whose adjacent newline-whitespace is purely formatting.
// `pre` is intentionally excluded — whitespace inside it is significant.
const EDITOR_BLOCK_TAGS = 'p|div|h[1-6]|blockquote|ul|ol|li|dl|dt|dd|center|hr|br|table|thead|tbody|tr|td|th'
const NL_AFTER_BLOCK = new RegExp(`(</?(?:${EDITOR_BLOCK_TAGS})\\b[^>]*>)\\s*\\n\\s*`, 'gi')
const NL_BEFORE_BLOCK = new RegExp(`\\s*\\n\\s*(</?(?:${EDITOR_BLOCK_TAGS})\\b[^>]*>)`, 'gi')

/**
 * Normalize HTML before handing it to TipTap (setContent / initial content).
 *
 * Runs breakTags (plain-text \n\n → <p>, idempotent on already-tagged content),
 * then strips newline-containing whitespace that sits immediately against a
 * block-level tag boundary.
 *
 * Why the second step: breakTags bails the moment it sees any <p>/<br>, so
 * MIXED content authored in HTML mode — e.g. "<p>Hello</p>\n\nHello" (a rich
 * paragraph plus a hand-typed plain one) — keeps its trailing "\n\nHello"
 * raw. TipTap wraps that loose text into a paragraph but preserves the
 * leading "\n\n" as a literal space, yielding "<p>Hello</p><p> Hello</p>"
 * with a stray leading space that throws off formatting (reported on the
 * rich/HTML mode round-trip). Removing the newline-whitespace that abuts the
 * block boundary leaves "<p>Hello</p>Hello", which TipTap wraps cleanly as
 * "<p>Hello</p><p>Hello</p>".
 *
 * Only newline-bearing whitespace is touched, so meaningful inline spaces
 * (e.g. a single space between <strong>/<em>) are preserved.
 */
export function normalizeEditorHtml(html) {
  if (!html) return ''
  let out = breakTags(html)
  out = out.replace(NL_AFTER_BLOCK, '$1').replace(NL_BEFORE_BLOCK, '$1')
  return out
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

// Placeholders for raw-literal entities during sanitization. DOMPurify decodes
// HTML entities while parsing \u2014 so `&#91;`/`&#93;` for bracketed text would
// become literal `[`/`]` and the E2 link parser would then see them as links,
// and `&#60;`/`&#62;` would become `<`/`>` and look like (probably unknown)
// tags that DOMPurify itself then strips. Replace with placeholders before
// DOMPurify, then restore after.
//
// Restoration char differs by type:
// - `[`/`]` restore to the literal char because the browser HTML renderer
//   doesn't care about them.
// - `<`/`>` restore to the entity form (`&lt;`/`&gt;`) because the eventual
//   serialized HTML needs them entity-encoded \u2014 restoring to a literal `<`
//   would re-introduce the original parse-as-tag bug at the next innerHTML.
const RAW_LEFT_BRACKET_PLACEHOLDER = '\uE000E2RAWLBRACKET\uE001'
const RAW_RIGHT_BRACKET_PLACEHOLDER = '\uE000E2RAWRBRACKET\uE001'
const RAW_LT_PLACEHOLDER = '\uE000E2RAWLT\uE001'
const RAW_GT_PLACEHOLDER = '\uE000E2RAWGT\uE001'

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

  // Protect raw-literal entities from DOMPurify's parse-time decode.
  // - &#91; / &#93; survive so the E2 link parser ignores them ([text] vs &#91;text&#93;).
  // - &#60; / &#62; survive so DOMPurify doesn't see `<text>` and strip it as a tag.
  processedHtml = processedHtml
    .replace(/&#91;/g, RAW_LEFT_BRACKET_PLACEHOLDER)
    .replace(/&#93;/g, RAW_RIGHT_BRACKET_PLACEHOLDER)
    .replace(/&#60;/g, RAW_LT_PLACEHOLDER)
    .replace(/&#62;/g, RAW_GT_PLACEHOLDER)

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

  // Restore raw-literal placeholders. See the RAW_*_PLACEHOLDER comment block
  // above for why `<`/`>` restore to the entity form and `[`/`]` restore literal.
  sanitized = sanitized
    .replace(new RegExp(RAW_LEFT_BRACKET_PLACEHOLDER, 'g'), '[')
    .replace(new RegExp(RAW_RIGHT_BRACKET_PLACEHOLDER, 'g'), ']')
    .replace(new RegExp(RAW_LT_PLACEHOLDER, 'g'), '&lt;')
    .replace(new RegExp(RAW_GT_PLACEHOLDER, 'g'), '&gt;')

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
