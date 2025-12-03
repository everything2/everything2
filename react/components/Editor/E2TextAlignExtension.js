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

        return this.options.types.every(type => commands.updateAttributes(type, { textAlign: alignment }));
      },

      unsetTextAlign: () => ({ commands }) => {
        return this.options.types.every(type => commands.resetAttributes(type, 'textAlign'));
      },
    };
  },
});

export default E2TextAlign;
