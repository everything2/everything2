(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-superscript"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

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

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
