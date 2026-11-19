const { test, expect } = require('@playwright/test')
const { loginAsE2EEditor, loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Node notes stay in the order they were written, even when several land in the same
 * second (notes are timestamped to the second, so same-second notes need a tiebreaker).
 *
 * e2e_editor adds notes from the Master Control "Node Notes" panel on a throwaway document:
 * three typed quickly one after another, and three more posted back to back through the
 * same API the panel uses (so they share a timestamp). After a reload the panel lists all
 * six in the order written. e2e_admin, unrecorded, deletes the document afterwards.
 * Master Control is put in the editor's sidebar for the run and the old sidebar restored after.
 * Watch: `./tools/e2e-demo.sh node-notes-order` (desktop: the panel is a sidebar nodelet).
 */
test('node notes are listed in the order they were written', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const editor = await demo.actor(browser, 'e2e_editor', '#38495e')
  const { page } = editor
  const adminCtx = await browser.newContext()
  const admin = await adminCtx.newPage()
  const stamp = Date.now().toString(36)
  let docId
  let nodeletsBefore

  const cleanup = async () => {
    if (nodeletsBefore) await page.request.post('/api/nodelets', { data: { nodelet_ids: nodeletsBefore } }).catch(() => {})
    if (docId) await admin.request.post(`/api/nodes/${docId}/action/delete`).catch(() => {})
    await adminCtx.close()
  }

  await demo.scenario('node-notes-order', [editor], async () => {
    await Promise.all([loginAsE2EEditor(page), loginAsE2EAdmin(admin)])

    // Setup: put Master Control (where editors see Node Notes) in the sidebar; restored after.
    const mc = await (await page.request.get(`/api/nodes/lookup/nodelet/${encodeURIComponent('Master Control')}`)).json()
    expect(mc && mc.node_id, 'Master Control nodelet').toBeTruthy()
    const current = await (await page.request.get('/api/nodelets')).json()
    nodeletsBefore = (current.nodelets || []).map((n) => Number(n.node_id))
    if (!nodeletsBefore.includes(Number(mc.node_id))) {
      const set = await page.request.post('/api/nodelets', { data: { nodelet_ids: [Number(mc.node_id), ...nodeletsBefore] } })
      expect((await set.json()).success).toBeTruthy()
    }

    const doc = await (await admin.request.post('/api/node/create', { data: { type: 'document', title: `Note order check ${stamp}` } })).json()
    expect(doc.node_id).toBeTruthy()
    docId = doc.node_id

    await page.goto(`/node/${docId}`)
    const panel = page.locator('#nodenotes')
    await expect(panel).toBeVisible({ timeout: 10000 })
    await demo.step(page, 'opens a document; Node Notes is in Master Control')
    await demo.show(panel)

    // 1. Three notes typed one after another in the panel.
    const input = panel.locator('.node-notes__input')
    const typed = ['first: checked the formatting', 'second: fixed two links', 'third: asked the author about the title']
    await demo.step(page, 'adds three notes, one after another')
    for (const text of typed) {
      await input.fill(text)
      const added = page.waitForResponse((r) => r.url().includes(`/api/nodenotes/${docId}/create`))
      await panel.locator('.node-notes__btn--add').click()
      expect((await added).status()).toBe(200)
      await expect(panel.locator('.node-notes__entry').last()).toContainText(text)
    }

    // 2. Three more in the same second, through the panel's own API.
    const burst = ['fourth: same second A', 'fifth: same second B', 'sixth: same second C']
    await demo.step(page, 'three more notes arrive in the same second')
    for (const text of burst) {
      const res = await page.request.post(`/api/nodenotes/${docId}/create`, { data: { notetext: text } })
      expect(res.status()).toBe(200)
    }

    // 3. After a reload, all six are listed in the order written.
    await page.reload()
    await demo.step(page, 'reloads the page')
    const entries = panel.locator('.node-notes__entry .node-notes__text')
    await expect(entries).toHaveCount(6, { timeout: 10000 })
    const texts = (await entries.allTextContents()).map((t) => t.replace(/\s+/g, ' '))
    const want = [...typed, ...burst]
    want.forEach((w, i) => expect(texts[i], `note ${i + 1}`).toContain(w))
    await demo.step(page, 'the notes are in the order they were written')
    await demo.show(panel, 2500)
  }, { cleanup })
})
