import { Node, mergeAttributes } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';

/**
 * E2Link Extension for Tiptap
 *
 * E2 uses a custom link syntax: [nodename|display text] or just [nodename]
 * This is converted to <a href="/node/nodename">display text</a> on render.
 *
 * In the editor, we store these as <e2link title="nodename">display text</e2link>
 * which gets converted to E2's [link] syntax on export.
 */
export const E2Link = Node.create({
  name: 'e2link',

  group: 'inline',

  inline: true,

  // Allow content inside the link (the display text)
  content: 'text*',

  // The 'title' attribute stores the node name to link to
  addAttributes() {
    return {
      title: {
        default: null,
        parseHTML: element => element.getAttribute('title'),
        renderHTML: attributes => {
          if (!attributes.title) {
            return {};
          }
          return { title: attributes.title };
        }
      }
    };
  },

  parseHTML() {
    return [
      {
        tag: 'e2link'
      },
      // Also parse standard anchor tags (for paste support)
      {
        tag: 'a[href]',
        getAttrs: element => {
          const href = element.getAttribute('href');
          // Extract node name from E2 URLs like /node/foo or /title/foo
          const match = href?.match(/\/(node|title)\/(.+?)(?:\?|$)/);
          if (match) {
            return { title: decodeURIComponent(match[2]) };
          }
          // For external links, use the href as title
          return { title: href };
        }
      }
    ];
  },

  renderHTML({ HTMLAttributes }) {
    return ['e2link', mergeAttributes(HTMLAttributes), 0];
  },

  addCommands() {
    return {
      setE2Link: attributes => ({ commands }) => {
        return commands.insertContent({
          type: this.name,
          attrs: attributes,
          content: [{ type: 'text', text: attributes.displayText || attributes.title }]
        });
      },

      toggleE2Link: attributes => ({ commands, state }) => {
        const { from, to } = state.selection;
        const selectedText = state.doc.textBetween(from, to, '');

        if (selectedText) {
          // Wrap selected text in an E2 link
          return commands.insertContent({
            type: this.name,
            attrs: { title: attributes.title || selectedText },
            content: [{ type: 'text', text: selectedText }]
          });
        }

        return false;
      },

      unsetE2Link: () => ({ commands }) => {
        return commands.lift(this.name);
      }
    };
  },

  addKeyboardShortcuts() {
    return {
      'Mod-k': () => {
        // Open link dialog (will be implemented in MenuBar)
        const event = new CustomEvent('e2-open-link-dialog');
        window.dispatchEvent(event);
        return true;
      }
    };
  },

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: new PluginKey('e2LinkClick'),
        props: {
          handleClick(view, pos, event) {
            // Handle clicks on E2 links in editor (could open edit dialog)
            const { schema, doc } = view.state;
            const node = doc.nodeAt(pos);

            if (node?.type.name === 'e2link') {
              // For now, just prevent default navigation
              // Could open an edit dialog here
              return false;
            }

            return false;
          }
        }
      })
    ];
  }
});

/**
 * Convert Tiptap HTML output to E2 [link] syntax
 *
 * @param {string} html - HTML from editor.getHTML()
 * @returns {string} - HTML with E2 link syntax
 */
export function convertToE2Syntax(html) {
  // Replace <e2link title="foo">bar</e2link> with [foo|bar] or [foo] if same
  return html.replace(
    /<e2link title="([^"]+)">([^<]*)<\/e2link>/g,
    (match, title, displayText) => {
      if (title === displayText || !displayText) {
        return `[${title}]`;
      }
      return `[${title}|${displayText}]`;
    }
  );
}

/**
 * Convert E2 [link] syntax to editor HTML
 *
 * @param {string} text - Text with E2 link syntax
 * @returns {string} - HTML suitable for editor
 */
export function convertFromE2Syntax(text) {
  // Replace [foo|bar] or [foo] with <e2link title="foo">bar</e2link>
  return text.replace(
    /\[([^\]|]+)(?:\|([^\]]+))?\]/g,
    (match, title, displayText) => {
      const display = displayText || title;
      return `<e2link title="${title}">${display}</e2link>`;
    }
  );
}

export default E2Link;
