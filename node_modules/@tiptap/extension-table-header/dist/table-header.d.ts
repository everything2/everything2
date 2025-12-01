import { Node } from '@tiptap/core';
export interface TableHeaderOptions {
    /**
     * The HTML attributes for a table header node.
     * @default {}
     * @example { class: 'foo' }
     */
    HTMLAttributes: Record<string, any>;
}
/**
 * This extension allows you to create table headers.
 * @see https://www.tiptap.dev/api/nodes/table-header
 */
export declare const TableHeader: Node<TableHeaderOptions, any>;
//# sourceMappingURL=table-header.d.ts.map