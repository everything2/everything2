import { Node, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create table cells.
 * @see https://www.tiptap.dev/api/nodes/table-cell
 */
const TableCell = Node.create({
    name: 'tableCell',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    content: 'block+',
    addAttributes() {
        return {
            colspan: {
                default: 1,
            },
            rowspan: {
                default: 1,
            },
            colwidth: {
                default: null,
                parseHTML: element => {
                    const colwidth = element.getAttribute('colwidth');
                    const value = colwidth
                        ? colwidth.split(',').map(width => parseInt(width, 10))
                        : null;
                    return value;
                },
            },
        };
    },
    tableRole: 'cell',
    isolating: true,
    parseHTML() {
        return [
            { tag: 'td' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['td', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
});

export { TableCell, TableCell as default };
//# sourceMappingURL=index.js.map
