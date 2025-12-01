import { Node } from '@tiptap/core';
export interface TableRowOptions {
    /**
     * The HTML attributes for a table row node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
/**
 * This extension allows you to create table rows.
 * @see https://www.tiptap.dev/api/nodes/table-row
 */
export declare const TableRow: Node<TableRowOptions, any>;
//# sourceMappingURL=table-row.d.ts.map