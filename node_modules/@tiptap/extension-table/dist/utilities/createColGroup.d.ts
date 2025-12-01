import { DOMOutputSpec, Node as ProseMirrorNode } from '@tiptap/pm/model';
export type ColGroup = {
    colgroup: DOMOutputSpec;
    tableWidth: string;
    tableMinWidth: string;
} | Record<string, never>;
/**
 * Creates a colgroup element for a table node in ProseMirror.
 *
 * @param node - The ProseMirror node representing the table.
 * @param cellMinWidth - The minimum width of a cell in the table.
 * @param overrideCol - (Optional) The index of the column to override the width of.
 * @param overrideValue - (Optional) The width value to use for the overridden column.
 * @returns An object containing the colgroup element, the total width of the table, and the minimum width of the table.
 */
export declare function createColGroup(node: ProseMirrorNode, cellMinWidth: number): ColGroup;
export declare function createColGroup(node: ProseMirrorNode, cellMinWidth: number, overrideCol: number, overrideValue: number): ColGroup;
//# sourceMappingURL=createColGroup.d.ts.map