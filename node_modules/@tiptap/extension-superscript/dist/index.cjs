'use strict';

Object.defineProperty(exports, '__esModule', { value: true });

var core = require('@tiptap/core');

/**
 * This extension allows you to create superscript text.
 * @see https://www.tiptap.dev/api/marks/superscript
 */
const Superscript = core.Mark.create({
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
        return ['sup', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
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

exports.Superscript = Superscript;
exports.default = Superscript;
//# sourceMappingURL=index.cjs.map
