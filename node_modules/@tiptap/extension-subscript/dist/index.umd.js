(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('@tiptap/core')) :
  typeof define === 'function' && define.amd ? define(['exports', '@tiptap/core'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global["@tiptap/extension-subscript"] = {}, global.core));
})(this, (function (exports, core) { 'use strict';

  /**
   * This extension allows you to create subscript text.
   * @see https://www.tiptap.dev/api/marks/subscript
   */
  const Subscript = core.Mark.create({
      name: 'subscript',
      addOptions() {
          return {
              HTMLAttributes: {},
          };
      },
      parseHTML() {
          return [
              {
                  tag: 'sub',
              },
              {
                  style: 'vertical-align',
                  getAttrs(value) {
                      // Don’t match this rule if the vertical align isn’t sub.
                      if (value !== 'sub') {
                          return false;
                      }
                      // If it falls through we’ll match, and this mark will be applied.
                      return null;
                  },
              },
          ];
      },
      renderHTML({ HTMLAttributes }) {
          return ['sub', core.mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
      },
      addCommands() {
          return {
              setSubscript: () => ({ commands }) => {
                  return commands.setMark(this.name);
              },
              toggleSubscript: () => ({ commands }) => {
                  return commands.toggleMark(this.name);
              },
              unsetSubscript: () => ({ commands }) => {
                  return commands.unsetMark(this.name);
              },
          };
      },
      addKeyboardShortcuts() {
          return {
              'Mod-,': () => this.editor.commands.toggleSubscript(),
          };
      },
  });

  exports.Subscript = Subscript;
  exports.default = Subscript;

  Object.defineProperty(exports, '__esModule', { value: true });

}));
//# sourceMappingURL=index.umd.js.map
