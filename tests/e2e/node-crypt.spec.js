const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * The Node Crypt and Dr. Nate's Secret Lab: a deleted node's stored copy can be viewed and the
 * node brought back.
 *
 * An admin deletes a draft (setup, through the drafts API: the same nuke path a member's delete
 * takes), finds it in The Node Crypt, opens its coffin to see the stored fields, and follows
 * RESURRECT to the Lab, which restores it. The restored draft opens with its title and text.
 * Cleanup deletes it again and removes that tomb row.
 * Watch: `./tools/e2e-demo.sh node-crypt`.
 */
test('an admin views a deleted node in The Node Crypt and resurrects it', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const admin = await demo.actor(browser, 'e2e_admin (admin)', '#38495e')
  const { page } = admin
  const stamp = Date.now()
  const title = `Crypt keeper draft ${stamp}`
  const text = `Brought back from the crypt ${stamp}.`
  let draftId = null

  const api = (path, method, body) =>
    page.evaluate(
      async ({ path, method, body }) => {
        const res = await fetch(path, {
          method,
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: body ? JSON.stringify(body) : undefined,
        })
        return res.json().catch(() => ({}))
      },
      { path, method, body }
    )

  const cleanup = async () => {
    if (!draftId) return
    await api(`/api/drafts/${draftId}`, 'DELETE').catch(() => {})
    await demo.shell(
      admin,
      `docker exec e2devdb mysql -u root -pblah everything -e "DELETE FROM tomb WHERE node_id=${Number(draftId)}" 2>/dev/null`,
      'removes the test draft from the tomb'
    )
  }

  await demo.scenario('node-crypt', [admin], async () => {
    await loginAsE2EAdmin(page)

    const created = await api('/api/drafts', 'POST', { title, doctext: `<p>${text}</p>` })
    expect(created.success).toBeTruthy()
    draftId = created.draft.node_id
    const deleted = await api(`/api/drafts/${draftId}`, 'DELETE')
    expect(deleted.success, JSON.stringify(deleted)).toBeTruthy()
    await demo.note(admin, 'Setup', `created and deleted the draft "${title}" (node ${draftId})`)

    await page.goto('/title/The%20Node%20Crypt')
    const entry = page.locator('.node-crypt__list-table a', { hasText: title })
    await expect(entry).toHaveCount(1, { timeout: 10000 })
    await demo.step(page, 'opens The Node Crypt and finds the deleted draft')
    await demo.show(entry)

    await demo.click(entry)
    const coffin = page.locator('.node-crypt__coffin-table')
    await expect(coffin).toBeVisible({ timeout: 10000 })
    const doctextRow = coffin.locator('tr', { hasText: 'doctext' })
    await expect(doctextRow).toContainText(text)
    await demo.step(page, 'opens its coffin: the stored copy, field by field')
    await demo.show(doctextRow)

    await demo.click(page.locator('.node-crypt__heading a', { hasText: 'RESURRECT' }))
    const done = page.locator('.dr-nates-lab__result--success')
    await expect(done).toContainText('Resurrected as', { timeout: 10000 })
    await demo.step(page, "follows RESURRECT: Dr. Nate's Secret Lab restores it")
    await demo.show(done)

    await demo.click(done.locator('.dr-nates-lab__node-link'))
    await expect(page.locator('body')).toContainText(title, { timeout: 10000 })
    await expect(page.locator('body')).toContainText(text)
    await demo.step(page, 'opens the restored draft')
    await demo.show(page.getByText(text).first())
  }, { cleanup })
})
