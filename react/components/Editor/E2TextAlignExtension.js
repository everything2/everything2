import { Extension } from '@tiptap/core';

/**
 * E2TextAlign - Custom text alignment extension for Everything2
 *
 * Uses the HTML `align` attribute instead of `style="text-align"`
 * because E2's HTML sanitizer doesn't whitelist the style attribute
 * (users could break the site), but does allow align= on tags.
 */
export const E2TextAlign = Extension.create({
  name: 'e2TextAlign',

  addOptions() {
    return {
      types: ['heading', 'paragraph'],
      alignments: ['left', 'center', 'right'],
      defaultAlignment: 'left',
    };
  },

  addGlobalAttributes() {
    return [
      {
        types: this.options.types,
        attributes: {
          textAlign: {
            default: this.options.defaultAlignment,
            parseHTML: element => element.getAttribute('align') || this.options.defaultAlignment,
            renderHTML: attributes => {
              if (attributes.textAlign === this.options.defaultAlignment) {
                return {};
              }

              return {
                align: attributes.textAlign,
              };
            },
          },
        },
      },
    ];
  },

  addCommands() {
    return {
      setTextAlign: alignment => ({ commands }) => {
        if (!this.options.alignments.includes(alignment)) {
          return false;
        }

        // map().some(), not every(): TipTap v3's updateAttributes returns false for a type that
        // isn't in the selection, and every() would stop before reaching the type that is.
        return this.options.types
          .map(type => commands.updateAttributes(type, { textAlign: alignment }))
          .some(Boolean);
      },

      unsetTextAlign: () => ({ commands }) => {
        return this.options.types
          .map(type => commands.resetAttributes(type, 'textAlign'))
          .some(Boolean);
      },
    };
  },
});

export default E2TextAlign;
