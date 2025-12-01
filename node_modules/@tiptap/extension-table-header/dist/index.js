import { Node, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create table headers.
 * @see https://www.tiptap.dev/api/nodes/table-header
 */
const TableHeader = Node.create({
    name: 'tableHeader',
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
    tableRole: 'header_cell',
    isolating: true,
    parseHTML() {
        return [
            { tag: 'th' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['th', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
});

export { TableHeader, TableHeader as default };
//# sourceMappingURL=index.js.map
