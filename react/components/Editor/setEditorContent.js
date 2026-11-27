import { normalizeEditorHtml } from './E2HtmlSanitizer'
import { convertEntitiesToRawBrackets } from './RawBracketExtension'

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
 * This sets the HTML exactly as given. For stored content (a writeup, a description, a bio) use
 * loadEditorContent, which prepares it first.
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

/**
 * Stored E2 HTML, ready for the editor: the one load pipeline every editor uses (#4756).
 *
 * - normalizeEditorHtml turns plain-text blank lines into paragraphs (breakTags) and drops
 *   newline whitespace against block tags, so mixed content doesn't pick up stray spaces;
 * - convertEntitiesToRawBrackets turns the stored &#91; &#93; &#60; &#62; into protected marks.
 *   Without it a literal "[" loads as a plain bracket, and saving (convertRawBracketsToEntities
 *   only escapes the marks) writes it back as a live [link].
 *
 * Use it for the initial `content` passed to useEditor.
 */
export function prepareEditorContent(html) {
  return convertEntitiesToRawBrackets(normalizeEditorHtml(html || ''))
}

/**
 * Load stored E2 HTML into an editor: prepareEditorContent, then setEditorContent (so a missing
 * or destroyed editor is skipped). Use it wherever stored content goes into an editor after it's
 * created: switching back to rich mode, loading a draft, restoring a version.
 *
 * @returns {boolean} true if the content was set
 */
export function loadEditorContent(editor, html) {
  return setEditorContent(editor, prepareEditorContent(html))
}
