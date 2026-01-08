/**
 * Text utility functions for E2
 */

/**
 * Decode HTML entities in a string using the browser's built-in parser.
 * Handles both named entities (&amp;, &lt;, etc.) and numeric entities (&#123;, &#x7B;).
 *
 * @param {string} str - String potentially containing HTML entities
 * @returns {string} - String with entities decoded to their character equivalents
 */
export const decodeHtmlEntities = (str) => {
  if (!str || typeof str !== 'string') return str

  // Use a textarea element to decode entities - this is the most reliable
  // browser-native approach that handles all entity types
  const textarea = document.createElement('textarea')
  textarea.innerHTML = str
  return textarea.value
}
