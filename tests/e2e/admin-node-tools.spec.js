const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Admin node tools, as an admin uses them:
 *   - basic edit: change a node's title on its basicedit page;
 *   - nodegroups: remove a member in the group's "Edit Members" editor;
 *   - polls: make a poll current in the Poll Directory, vote, then use the admin "delete vote" control;
 *   - dbtable pages: the table's columns and indexes are listed.
 *
 * Fixtures are throwaway (a document and a nodegroup created through the API, deleted after).
 * Watch: `./tools/e2e-demo.sh admin-node-tools` (E2E_DEMO_DEVICE=mobile too).
 */
test('an admin edits a node, prunes a nodegroup, resets a poll vote and views a table', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 90000)
  const admin = await demo.actor(browser, 'e2e_admin', '#38495e')
  const { page } = admin
  const stamp = Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
  const made = []
  const polls = []

  const post = async (path, data) => (await page.request.post(path, { data })).json()
  const lookup = async (type, title) => (await (await page.request.get(`/api/nodes/lookup/${type}/${encodeURIComponent(title)}`)).json())
  const cleanup = async () => {
    for (const id of polls) await page.request.post('/api/polls/delete', { data: { poll_id: id } }).catch(() => {})
    for (const id of made.reverse()) await page.request.post(`/api/nodes/${id}/action/delete`).catch(() => {})
  }

  await demo.scenario('admin-node-tools', [admin], async () => {
    await loginAsE2EAdmin(page)
    // Removing members and deleting a vote ask with the browser's confirm dialog: say OK.
    page.on('dialog', (d) => d.accept())

    // 1. Basic edit: rename a throwaway document.
    const doc = await post('/api/node/create', { type: 'document', title: `Admin edit check ${stamp}` })
    expect(doc.node_id).toBeTruthy()
    made.push(doc.node_id)
    await page.goto(`/node/${doc.node_id}?displaytype=basicedit`)
    await demo.step(page, 'opens basic edit on a document')
    const titleField = page.locator('.system-node-editor__field', { has: page.locator('label', { hasText: /^\s*title\b/ }) }).locator('input, textarea').first()
    await expect(titleField).toHaveValue(`Admin edit check ${stamp}`, { timeout: 10000 })
    await titleField.fill(`Admin edit check ${stamp} (renamed)`)
    const saved = page.waitForResponse((r) => r.url().includes(`/api/admin/node/${doc.node_id}/basicedit`) && r.request().method() === 'POST')
    await demo.step(page, 'renames it and saves')
    await demo.click(page.locator('.system-node-editor__btn--save'))
    const savedBody = await (await saved).json()
    expect(savedBody.success).toBe(1)
    expect(savedBody.updatedFields).toEqual(['title'])
    await page.goto(`/node/${doc.node_id}`)
    await expect(page.locator('h1').first()).toContainText('(renamed)')
    await demo.step(page, 'the document has its new title')
    await demo.show(page.locator('h1').first())

    // 2. Nodegroups: remove a member in the editor.
    const group = await post('/api/node/create', { type: 'nodegroup', title: `Admin group check ${stamp}` })
    expect(group.node_id).toBeTruthy()
    made.push(group.node_id)
    const member = await lookup('e2node', 'historical origins of the beverage')
    const other = await lookup('e2node', 'cupping protocols and evaluation')
    const addRes = await post(`/api/nodegroups/${group.node_id}/action/addnode`, { node_ids: [member.node_id, other.node_id] })
    expect(addRes.success).toBeTruthy()
    await page.goto(`/node/${group.node_id}`)
    await demo.step(page, 'opens a nodegroup and edits its members')
    await demo.click(page.getByRole('button', { name: /Edit Members/i }))
    const row = page.locator('.group-editor__member, [class*="group-editor__member-row"], [class*="group-editor__member-item"]').filter({ hasText: member.title }).first()
    await expect(row).toBeVisible({ timeout: 10000 })
    const removed = page.waitForResponse((r) => r.url().includes(`/api/nodegroups/${group.node_id}/action/removenode`))
    await demo.step(page, `removes "${member.title}"`)
    await demo.click(row.locator('.group-editor__remove-btn'))
    expect((await (await removed).json()).success).toBeTruthy()
    await page.goto(`/node/${group.node_id}`)
    const list = page.locator('.nodegroup__member-list')
    await expect(list.locator('.nodegroup__member-item')).toHaveCount(1, { timeout: 10000 })
    await expect(list).toContainText(other.title)
    await expect(list).not.toContainText(member.title)
    await demo.step(page, `the group keeps only "${other.title}"`)
    await demo.show(list)

    // 3. Polls: make a throwaway poll current with the Poll Directory's "make current" button,
    // vote on it, then remove the vote with the admin "delete vote" control. The poll is deleted
    // afterwards. The vote can land on any worker, so it also shows every worker sees it as current.
    const pollTitle = `Admin poll check ${stamp}`
    const created = await post('/api/poll_creator/create', { title: pollTitle, question: 'Pick one', options: ['Apples', 'Pears'] })
    expect(created.success, JSON.stringify(created)).toBeTruthy()
    const pollId = Number(created.poll_id)
    polls.push(pollId)
    await page.goto('/title/Everything%20Poll%20Directory')
    const pollRow = page.locator('.poll-directory__item', { has: page.locator('.poll-display__title', { hasText: pollTitle }) })
    const makeCurrent = pollRow.locator('button', { hasText: 'make current' })
    await expect(makeCurrent).toBeVisible({ timeout: 10000 })
    await demo.step(page, `opens the Poll Directory and makes "${pollTitle}" current`)
    const setCurrent = page.waitForResponse((r) => r.url().includes('/api/polls/set_current'))
    await demo.click(makeCurrent)
    expect((await (await setCurrent).json()).success).toBeTruthy()
    await expect(pollRow.locator('.poll-display__title')).toContainText('(current)', { timeout: 10000 })
    await expect(makeCurrent).toHaveCount(0)
    await demo.step(page, 'the directory lists it as current')
    await demo.show(pollRow.locator('.poll-display__title'))
    await page.goto(`/node/${pollId}`)
    await demo.step(page, 'opens the current poll and votes')
    await page.locator('.poll-display__radio').first().check()
    const voted = page.waitForResponse((r) => /\/api\/poll\/vote/.test(r.url()))
    await demo.click(page.locator('.poll-display__vote-btn'))
    const voteBody = await (await voted).json()
    expect(voteBody.success, JSON.stringify(voteBody)).toBeTruthy()
    const deleteBtn = page.locator('.poll-display__delete-btn')
    await expect(deleteBtn).toBeVisible({ timeout: 10000 })
    const deleted = page.waitForResponse((r) => r.url().includes('/api/poll/delete_vote'))
    await demo.step(page, 'deletes the vote with the admin control')
    await demo.click(deleteBtn)
    expect((await deleted).status()).toBe(200)
    await expect(page.locator('.poll-display__vote-btn')).toBeVisible({ timeout: 10000 })
    await demo.step(page, 'the poll is open to vote again')
    await demo.show(page.locator('.poll-display').first())

    // 4. dbtable pages list columns and indexes.
    const table = await lookup('dbtable', 'vote')
    await page.goto(`/node/${table.node_id}`)
    const indexes = page.locator('.dbtable__section-title', { hasText: 'Indexes' })
    await expect(indexes).toBeVisible({ timeout: 10000 })
    await expect(indexes).not.toHaveText(/\(0\)/)
    await demo.step(page, 'the vote table page lists its indexes')
    await demo.show(indexes, 2000)
  }, { cleanup })
})
