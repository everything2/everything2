/**
 * Load HTML into a TipTap editor without firing an update, if the editor can take it.
 *
 * TipTap v3's useEditor can hand a component an editor it has already destroyed: it schedules a
 * "destroy unless mounted" timer when the component first renders, and if that fires before
 * React runs the component's effects, those effects see the destroyed instance (the replacement
 * arrives on the next render). A destroyed editor's commands are gone, so calling
 * editor.commands.setContent throws, and an uncaught throw in an effect unmounts the whole page
 * (#4639). This does nothing for a missing or destroyed editor; an effect that depends on
 * `editor` re-runs with the replacement, so the content still loads.
 *
 * Only for loading content. Don't guard reading content for a save the same way: falling back
 * to '' there would save an empty document. Let those throw.
 *
 * @returns {boolean} true if the content was set
 */
export default function setEditorContent(editor, html) {
  if (!editor || editor.isDestroyed) return false
  editor.commands.setContent(html, { emitUpdate: false })
  return true
}
