import { Mark } from '@tiptap/core';

/**
 * RawBracket Extension - Allows inserting literal brackets that won't be parsed as E2 links
 *
 * Creates special marks for left and right brackets that render as HTML entities:
 * - Left bracket: &#91; (&lsqb;)
 * - Right bracket: &#93; (&rsqb;)
 *
 * This prevents E2's link parser from treating [text] as a link.
 *
 * Usage:
 * - Toolbar buttons insert these special brackets
 * - They display as [ and ] in the editor
 * - They serialize to &#91; and &#93; in HTML output
 */

export const RawBracket = Mark.create({
  name: 'rawBracket',

  addAttributes() {
    return {
      type: {
        default: 'left',
        parseHTML: element => element.getAttribute('data-bracket-type'),
        renderHTML: attributes => {
          return {
            'data-bracket-type': attributes.type
          };
        }
      }
    };
  },

  parseHTML() {
    return [
      {
        tag: 'span[data-bracket-type]',
        getAttrs: element => {
          const type = element.getAttribute('data-bracket-type');
          return type === 'left' || type === 'right' ? { type } : false;
        }
      }
    ];
  },

  renderHTML({ HTMLAttributes }) {
    const bracket = HTMLAttributes['data-bracket-type'] === 'left' ? '[' : ']';
    return ['span', { ...HTMLAttributes, class: 'raw-bracket' }, bracket];
  },

  addCommands() {
    return {
      insertRawLeftBracket: () => ({ commands }) => {
        return commands.insertContent({
          type: 'text',
          text: '[',
          marks: [{ type: this.name, attrs: { type: 'left' } }]
        });
      },
      insertRawRightBracket: () => ({ commands }) => {
        return commands.insertContent({
          type: 'text',
          text: ']',
          marks: [{ type: this.name, attrs: { type: 'right' } }]
        });
      }
    };
  }
});

/**
 * Convert raw bracket marks to HTML entities in final output
 *
 * This function should be called on the HTML output before saving.
 * It converts <span data-bracket-type="left">[</span> to &#91;
 * and <span data-bracket-type="right">]</span> to &#93;
 */
export function convertRawBracketsToEntities(html) {
  return html
    .replace(/<span[^>]*data-bracket-type="left"[^>]*>\[<\/span>/g, '&#91;')
    .replace(/<span[^>]*data-bracket-type="right"[^>]*>\]<\/span>/g, '&#93;');
}

export default RawBracket;
