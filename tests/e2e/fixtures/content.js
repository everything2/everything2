// Shared helpers for creating object-model content in e2e tests.
//
// These exercise the real node lifecycle (draft creation, e2node attach, and the
// in-place draft->writeup type conversion) so other specs can build on published
// content without hand-rolling the 3-step publish dance.

async function getWriteuptypeId(page, title = 'thing') {
  const resp = await page.request.get('/api/writeuptypes')
  const data = await resp.json()
  const types = data.writeuptypes || []
  const wt = types.find((w) => w.title === title) || types[0]
  return wt && wt.node_id
}

/**
 * Create a PUBLISHED writeup owned by the currently-logged-in user.
 *
 * draft create -> set parent e2node -> publish (converts the draft node in place
 * to a writeup). Returns { draftId, e2nodeId, writeupId } where writeupId ===
 * draftId (same node, new type).
 *
 * Throws with the offending API payload if any step fails, so callers get a
 * useful message rather than a downstream undefined.
 */
async function createWriteup(page, opts = {}) {
  const title = opts.title || `E2E writeup ${Date.now()}`
  const doctext = opts.doctext || '<p>e2e writeup body</p>'
  const e2nodeTitle = opts.e2nodeTitle || title
  const writeuptypeId = opts.writeuptypeId || (await getWriteuptypeId(page))
  if (!writeuptypeId) throw new Error('could not resolve a writeuptype id')

  const draft = await (await page.request.post('/api/drafts', {
    data: { title, doctext },
  })).json()
  const draftId = draft.draft && draft.draft.node_id
  if (!draftId) throw new Error('draft create failed: ' + JSON.stringify(draft))

  const parent = await (await page.request.post(`/api/drafts/${draftId}/parent`, {
    data: { e2node_title: e2nodeTitle, e2node_id: null },
  })).json()
  const e2nodeId = parent.e2node && parent.e2node.node_id
  if (!e2nodeId) throw new Error('set parent failed: ' + JSON.stringify(parent))

  const pub = await (await page.request.post(`/api/drafts/${draftId}/publish`, {
    data: {
      parent_e2node: e2nodeId,
      wrtype_writeuptype: writeuptypeId,
      feedback_policy_id: 0,
      notnew: 0,
    },
  })).json()
  if (!pub.success) throw new Error('publish failed: ' + JSON.stringify(pub))

  return { draftId, e2nodeId, writeupId: draftId }
}

module.exports = { createWriteup, getWriteuptypeId }
