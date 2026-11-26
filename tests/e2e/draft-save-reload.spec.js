const { test, expect } = require('@playwright/test')
const { loginAsE2EUser } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Saving a draft, as a writer does: open the draft, Edit, rewrite the text, Save. Every load of
 * the draft afterwards shows the saved text, whichever worker serves it, and so does the editor
 * the next time it's opened (it starts from the page's text, and autosaves whatever it starts
 * with). The draft is viewed many times first, so every worker has it cached before the save.
 *
 * e2e_user owns the draft (created through the API as setup) and deletes it afterwards.
 * Watch: `./tools/e2e-demo.sh draft-save-reload` (E2E_DEMO_DEVICE=mobile too).
 */
const LOADS = 40

test('a writer saves a draft and every reload shows the new text', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 90000)
  const writer = await demo.actor(browser, 'e2e_user (writer)', '#38495e')
  const { page } = writer
  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
  const before = `First thoughts ${stamp}`
  const after = `Second thoughts ${stamp}`
  let draftId

  const cleanup = async () => {
    if (draftId) await page.request.delete(`/api/drafts/${draftId}`).catch(() => {})
  }

  // How many of `LOADS` page loads (spread over the workers) show each version of the text.
  const loadMany = async () => {
    const counts = { before: 0, after: 0 }
    for (let i = 0; i < LOADS; i++) {
      const html = await (await page.request.get(`/node/${draftId}`)).text()
      if (html.includes(before)) counts.before++
      if (html.includes(after)) counts.after++
    }
    return counts
  }

  await demo.scenario('draft-save-reload', [writer], async () => {
    await loginAsE2EUser(page)

    const created = await (await page.request.post('/api/drafts', {
      data: { title: `Saving drafts ${stamp}`, doctext: `<p>${before}</p>` },
    })).json()
    expect(created.success).toBeTruthy()
    draftId = created.draft.node_id

    const warm = await loadMany()
    await demo.note(writer, 'Setup', `a new draft, loaded ${LOADS} times so every worker has it cached`)
    expect(warm.before, 'every load before the save shows the first text').toBe(LOADS)

    await demo.step(page, 'opens the draft')
    await page.goto(`/node/${draftId}`)
    const shown = page.locator('.draft-page .content')
    await expect(shown).toContainText(before, { timeout: 10000 })
    await demo.show(shown)

    await demo.step(page, 'clicks Edit and rewrites the text')
    await demo.click(page.locator('.draft-page__toolbar .e2-action-chip', { hasText: 'Edit' }))
    const editor = page.locator('[role="textbox"][aria-label="Writeup content"]')
      .or(page.locator('.inline-editor textarea')).first()
    await editor.waitFor({ timeout: 10000 })
    await editor.fill(after)

    await demo.step(page, 'clicks Save')
    await demo.click(page.locator('.inline-editor-btn--save'))
    const status = page.locator('.inline-editor-status')
    await expect(status).toContainText('All changes saved', { timeout: 10000 })
    await demo.show(status)

    await demo.step(page, 'reloads the draft')
    await page.reload()
    await expect(shown).toContainText(after, { timeout: 10000 })
    await expect(shown).not.toContainText(before)
    await demo.show(shown)

    const seen = await loadMany()
    await demo.note(writer, 'Reloads', `${LOADS} more loads: ${seen.after} show the saved text, ${seen.before} the old text`)
    expect(seen.before, 'no load after the save shows the old text').toBe(0)
    expect(seen.after, 'every load after the save shows the saved text').toBe(LOADS)

    await demo.step(page, 'opens the editor again')
    await demo.click(page.locator('.draft-page__toolbar .e2-action-chip', { hasText: 'Edit' }))
    await expect(editor).toContainText(after, { timeout: 10000 })
    await demo.show(editor)
  }, { cleanup })
})
