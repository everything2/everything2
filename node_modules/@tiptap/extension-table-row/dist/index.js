import { Node, mergeAttributes } from '@tiptap/core';

/**
 * This extension allows you to create table rows.
 * @see https://www.tiptap.dev/api/nodes/table-row
 */
const TableRow = Node.create({
    name: 'tableRow',
    addOptions() {
        return {
            HTMLAttributes: {},
        };
    },
    content: '(tableCell | tableHeader)*',
    tableRole: 'row',
    parseHTML() {
        return [
            { tag: 'tr' },
        ];
    },
    renderHTML({ HTMLAttributes }) {
        return ['tr', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes), 0];
    },
});

export { TableRow, TableRow as default };
//# sourceMappingURL=index.js.map
