import { Mark, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create superscript text.
 * @see https://www.tiptap.dev/api/marks/superscript
 */
const Superscript = Mark.create({
    name: 'superscript',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    parseHTML() {
        return [
            {
                tag: 'sup',
            },
            {
                style: 'vertical-align',
                getAttrs(value) {
                    // Don’t match this rule if the vertical align isn’t super.
                    if (value !== 'super') {
                        return false;
                    }
                    // If it falls through we’ll match, and this mark will be applied.
                    return null;
                },
            },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['sup', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
    addCommands() {
        return {
            setSuperscript: () => ({ commands }) => {
                return commands.setMark(this.name);
            },
            toggleSuperscript: () => ({ commands }) => {
                return commands.toggleMark(this.name);
            },
            unsetSuperscript: () => ({ commands }) => {
                return commands.unsetMark(this.name);
            },
        };
    },
    addKeyboardShortcuts() {
        return {
            'Mod-.': () => this.editor.commands.toggleSuperscript(),
        };
    },
});

export { Superscript, Superscript as default };
//# sourceMappingURL=index.js.map
