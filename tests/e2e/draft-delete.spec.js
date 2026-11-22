const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAsE2EUser, loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * A member deletes one of their drafts, and The Node Crypt shows that member as the one who
 * deleted it (#4718; it used to show the internal superuser).
 *
 * Setup (API, as the member): create a draft with a unique title. The member opens it, clicks
 * Delete and confirms, and lands back on their Drafts list. The admin, already browsing, opens The
 * Node Crypt and finds the draft with the member in the Killa column. Cleanup removes its tomb row.
 * Watch: `./tools/e2e-demo.sh draft-delete`.
 */
test('a member deletes a draft and The Node Crypt shows who deleted it', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const member = await demo.actor(browser, 'e2e_user (member)', '#2f6f8f')
  const admin = await demo.actor(browser, 'e2e_admin (admin)', '#38495e')
  const stamp = Date.now()
  const title = `Draft to delete ${stamp}`
  let draftId = null

  const cleanup = async () => {
    if (!draftId) return
    await demo.shell(
      admin,
      `docker exec e2devdb mysql -u root -pblah everything -e "DELETE FROM tomb WHERE node_id=${Number(draftId)}; DELETE FROM draft WHERE draft_id=${Number(draftId)}; DELETE FROM document WHERE document_id=${Number(draftId)}; DELETE FROM node WHERE node_id=${Number(draftId)}" 2>/dev/null`,
      'removes the test draft from the tomb'
    )
  }

  await demo.scenario('draft-delete', [member, admin], async () => {
    await Promise.all([loginAsE2EUser(member.page), loginAsE2EAdmin(admin.page)])

    const created = await member.page.evaluate(async (title) => {
      const res = await fetch('/api/drafts', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, doctext: '<p>Not long for this world.</p>' }),
      })
      return res.json()
    }, title)
    expect(created.success, JSON.stringify(created)).toBeTruthy()
    draftId = created.draft.node_id
    await demo.note(member, 'Setup', `created the draft "${title}" (node ${draftId})`)

    await member.page.goto(`/?node_id=${draftId}`)
    const del = member.page.locator('button[title="Delete this draft"]')
    await expect(del).toBeVisible({ timeout: 10000 })
    await demo.step(member.page, 'opens the draft and clicks Delete')
    member.page.once('dialog', (dialog) => dialog.accept())
    await demo.click(del)
    await member.page.waitForURL(/Drafts/, { timeout: 10000 })
    await expect(member.page.locator('body')).not.toContainText(title)
    await demo.step(member.page, 'confirms: back on the Drafts list, and the draft is gone')
    await demo.show(member.page.locator('h1, .page-header__title').first())

    await admin.page.goto('/title/The%20Node%20Crypt')
    const row = admin.page.locator('.node-crypt__list-table tr', { hasText: title })
    await expect(row).toHaveCount(1, { timeout: 10000 })
    const killa = row.locator('td').nth(3)
    await expect(killa).toHaveText('e2e_user')
    await demo.step(admin.page, 'opens The Node Crypt: the member is shown as the one who deleted it')
    await demo.show(row)
  }, { cleanup })
})
