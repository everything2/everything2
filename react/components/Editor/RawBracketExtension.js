import { Node } from '@tiptap/core';

/**
 * RawBracket Extension - Allows inserting literal characters that would otherwise be
 * eaten by E2's link parser ([, ]) or by the HTML sanitizer (<, >).
 *
 * Uses a custom inline atom node that:
 * - Displays as [, ], <, or > in the editor
 * - Serializes to &#91;, &#93;, &#60;, or &#62; in HTML output via
 *   convertRawBracketsToEntities() (TipTap's array renderHTML treats the third
 *   element as text and would re-encode an entity to &amp;#91;).
 *
 * Why this exists:
 * - The E2 link parser treats [text] as a link, so a literal `[` needs to live
 *   as an entity in the saved content to survive the parser.
 * - DOMPurify (E2HtmlSanitizer) decodes entities while parsing HTML. A literal
 *   `<text>` looks like an unknown tag and gets stripped entirely; the entity
 *   form survives because the sanitizer placeholder-protects it (see
 *   E2HtmlSanitizer.js).
 *
 * The name `rawBracket` predates the angle-bracket addition (was [ ] only,
 * issue #3829). Kept for backward compatibility with existing drafts whose
 * stored HTML uses `data-raw-bracket` / node type `rawBracket`.
 */

// Map of supported type values to their display char + entity form.
// Add a new entry here to support another literal character without touching
// the rest of the file.
const RAW_CHAR_MAP = {
  left:  { char: '[', entity: '&#91;' },
  right: { char: ']', entity: '&#93;' },
  lt:    { char: '<', entity: '&#60;' },
  gt:    { char: '>', entity: '&#62;' },
};

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
    // Output a literal display char - TipTap's array syntax treats content as text
    // which would escape entities to &amp;#NN;. convertRawBracketsToEntities will
    // convert these span-wrapped chars to the entity form when saving.
    const entry = RAW_CHAR_MAP[node.attrs.type] || RAW_CHAR_MAP.left;
    return ['span', { 'data-raw-bracket': 'true', 'data-bracket-type': node.attrs.type }, entry.char];
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
      },
      insertRawLessThan: () => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: { type: 'lt' }
        });
      },
      insertRawGreaterThan: () => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: { type: 'gt' }
        });
      }
    };
  }
});

/**
 * Convert raw bracket nodes to HTML entities in final output.
 *
 * Handles span-wrapped marks for all four characters (left/right bracket,
 * less-than, greater-than) in any attribute order, with either the literal
 * display character or the entity already in the inner text. Also folds
 * naturally-typed `&lt;` / `&gt;` (TipTap's default encoding for typed `<`/`>`)
 * to `&#60;` / `&#62;` so they share the sanitizer placeholder path with the
 * button-inserted form — without this, typed angle brackets survive the
 * round trip but get rewritten through `&lt;` and confuse the rich-mode load
 * path on re-edit.
 */
// `display` is the regex-escaped form that appears inside the span when
// editor.getHTML() serializes the atom node. For `<`/`>` the renderHTML emits
// a literal char into the DOM but the HTML serializer escapes it to `&lt;`/
// `&gt;` — so that's what we match here, not the raw character.
const SPAN_INNER_PATTERNS = {
  left:  { display: '\\[',  entity: '&#91;' },
  right: { display: '\\]',  entity: '&#93;' },
  lt:    { display: '&lt;', entity: '&#60;' },
  gt:    { display: '&gt;', entity: '&#62;' },
};

function buildSpanReplacements() {
  const types = Object.keys(SPAN_INNER_PATTERNS);
  const out = [];
  for (const type of types) {
    const { display, entity } = SPAN_INNER_PATTERNS[type];
    // 4 attribute-order × inner-content combinations per type
    const innerVariants = [display, entity];
    for (const inner of innerVariants) {
      out.push({
        re: new RegExp(`<span[^>]*data-raw-bracket="true"[^>]*data-bracket-type="${type}"[^>]*>${inner}<\\/span>`, 'g'),
        sub: entity,
      });
      out.push({
        re: new RegExp(`<span[^>]*data-bracket-type="${type}"[^>]*data-raw-bracket="true"[^>]*>${inner}<\\/span>`, 'g'),
        sub: entity,
      });
    }
    // Older format without data-raw-bracket
    out.push({
      re: new RegExp(`<span[^>]*data-bracket-type="${type}"[^>]*>${display}<\\/span>`, 'g'),
      sub: entity,
    });
  }
  return out;
}

const SPAN_REPLACEMENTS = buildSpanReplacements();

export function convertRawBracketsToEntities(html) {
  if (!html) return html;
  let out = html;
  for (const { re, sub } of SPAN_REPLACEMENTS) {
    out = out.replace(re, sub);
  }
  // Fold typed `&lt;` / `&gt;` to their numeric form so the sanitizer's
  // placeholder pass (which keys on `&#60;`/`&#62;`) preserves them through
  // DOMPurify's decode-and-reparse. Without this, typed angle brackets
  // survive a single save but the rich-mode loader sees `&lt;text&gt;`,
  // TipTap's HTML parser decodes the entity, and DOMPurify on a later save
  // strips the resulting `<text>` as an unknown tag.
  return out
    .replace(/&lt;/g, '&#60;')
    .replace(/&gt;/g, '&#62;');
}

/**
 * Convert HTML entities back to span-wrapped format for editor parsing
 *
 * When content is loaded from the database, the entity forms (&#91;, &#93;,
 * &#60;, &#62;) are stored as plain text. Before passing to TipTap we wrap
 * each one in the atom-node span so the editor renders the display char and
 * the user can delete it as a unit.
 *
 * Inverse of convertRawBracketsToEntities.
 */
export function convertEntitiesToRawBrackets(html) {
  if (!html) return html;
  return html
    .replace(/&#91;/g, '<span data-raw-bracket="true" data-bracket-type="left">[</span>')
    .replace(/&#93;/g, '<span data-raw-bracket="true" data-bracket-type="right">]</span>')
    .replace(/&#60;/g, '<span data-raw-bracket="true" data-bracket-type="lt">&lt;</span>')
    .replace(/&#62;/g, '<span data-raw-bracket="true" data-bracket-type="gt">&gt;</span>');
}

export default RawBracket;
