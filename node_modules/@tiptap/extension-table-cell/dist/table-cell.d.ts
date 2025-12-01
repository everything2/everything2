import { Node } from '@tiptap/core';
export interface TableCellOptions {
    /**
     * The HTML attributes for a table cell node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
/**
 * This extension allows you to create table cells.
 * @see https://www.tiptap.dev/api/nodes/table-cell
 */
export declare const TableCell: Node<TableCellOptions, any>;
//# sourceMappingURL=table-cell.d.ts.map