import { Node } from '@tiptap/core';

/**
 * RawBracket Extension - Allows inserting literal brackets that won't be parsed as E2 links
 *
 * Uses a custom inline node that:
 * - Displays as [ or ] in the editor
 * - Serializes to &#91; or &#93; in HTML output (not escaped by TipTap)
 *
 * This prevents E2's link parser from treating [text] as a link.
 */

export const RawBracket = Node.create({
  name: 'rawBracket',
  group: 'inline',
  inline: true,
  atom: true, // Cannot be edited, only inserted/deleted as a unit

  addAttributes() {
    return {
      type: {
        default: 'left',
        parseHTML: element => element.getAttribute('data-bracket-type') || 'left',
        renderHTML: attributes => ({
          'data-bracket-type': attributes.type
        })
      }
    };
  },

  parseHTML() {
    return [
      {
        // Match spans with data-raw-bracket attribute (our new format)
        tag: 'span[data-raw-bracket]',
        getAttrs: element => ({
          type: element.getAttribute('data-bracket-type') || 'left'
        })
      },
      {
        // Match spans with just data-bracket-type (legacy format, or after browser decodes entities)
        tag: 'span[data-bracket-type]',
        getAttrs: element => ({
          type: element.getAttribute('data-bracket-type') || 'left'
        })
      }
    ];
  },

  renderHTML({ node }) {
    // Output a literal bracket character - TipTap's array syntax treats content as text
    // which would escape &#91; to &amp;#91;. The convertRawBracketsToEntities function
    // will convert these span-wrapped brackets to &#91;/&#93; entities when saving.
    const bracket = node.attrs.type === 'left' ? '[' : ']';
    return ['span', { 'data-raw-bracket': 'true', 'data-bracket-type': node.attrs.type }, bracket];
  },

  addCommands() {
    return {
      insertRawLeftBracket: () => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: { type: 'left' }
        });
      },
      insertRawRightBracket: () => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: { type: 'right' }
        });
      }
    };
  }
});

/**
 * Convert raw bracket nodes to HTML entities in final output
 *
 * This function converts the span-wrapped brackets to plain entities:
 * - <span data-raw-bracket="true" data-bracket-type="left">[</span> to &#91;
 * - <span data-raw-bracket="true" data-bracket-type="right">]</span> to &#93;
 *
 * Handles various formats:
 * - Literal brackets [ and ] (current format from TipTap)
 * - Entity brackets &#91; and &#93; (legacy/loaded from database)
 * - Various attribute orderings
 */
export function convertRawBracketsToEntities(html) {
  if (!html) return html;
  return html
    // Current format with literal brackets: <span data-raw-bracket="true" data-bracket-type="left">[</span>
    .replace(/<span[^>]*data-raw-bracket="true"[^>]*data-bracket-type="left"[^>]*>\[<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-raw-bracket="true"[^>]*data-bracket-type="right"[^>]*>\]<\/span>/g, '&#93;')
    // Handle attribute order variations with literal brackets
    .replace(/<span[^>]*data-bracket-type="left"[^>]*data-raw-bracket="true"[^>]*>\[<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-bracket-type="right"[^>]*data-raw-bracket="true"[^>]*>\]<\/span>/g, '&#93;')
    // Legacy format with entities: <span ...>&#91;</span>
    .replace(/<span[^>]*data-raw-bracket="true"[^>]*data-bracket-type="left"[^>]*>&#91;<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-raw-bracket="true"[^>]*data-bracket-type="right"[^>]*>&#93;<\/span>/g, '&#93;')
    .replace(/<span[^>]*data-bracket-type="left"[^>]*data-raw-bracket="true"[^>]*>&#91;<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-bracket-type="right"[^>]*data-raw-bracket="true"[^>]*>&#93;<\/span>/g, '&#93;')
    // Older format without data-raw-bracket: <span data-bracket-type="left">[</span>
    .replace(/<span[^>]*data-bracket-type="left"[^>]*>\[<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-bracket-type="right"[^>]*>\]<\/span>/g, '&#93;');
}

/**
 * Convert HTML entities back to span-wrapped format for editor parsing
 *
 * When content is loaded from the database, &#91; and &#93; entities are stored
 * as plain text. Before passing to TipTap, we need to convert them back to
 * the span-wrapped format that parseHTML can recognize.
 *
 * This is the inverse of convertRawBracketsToEntities.
 */
export function convertEntitiesToRawBrackets(html) {
  if (!html) return html;
  return html
    // Convert &#91; entity to span-wrapped format
    .replace(/&#91;/g, '<span data-raw-bracket="true" data-bracket-type="left">[</span>')
    // Convert &#93; entity to span-wrapped format
    .replace(/&#93;/g, '<span data-raw-bracket="true" data-bracket-type="right">]</span>');
}

export default RawBracket;
