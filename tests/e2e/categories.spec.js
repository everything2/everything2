const { test, expect } = require('@playwright/test')
const { loginAsE2EEditor, loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Categories, as a member uses them:
 *   - add a node to your category from the node's "Add to Category" button;
 *   - on the category's edit page, remove a member, move another to the top (keyboard drag),
 *     and save the order;
 *   - the category page then lists what's left;
 *   - a node page still renders normally when an old link asks for ?displaytype=printable.
 *
 * e2e_editor owns the category (created through the API as setup; Add to Category shows for
 * users above level 1 or editors); e2e_admin, unrecorded,
 * deletes it afterwards. Watch: `./tools/e2e-demo.sh categories` (E2E_DEMO_DEVICE=mobile too).
 */
test('a member adds to, prunes and reorders their category', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const user = await demo.actor(browser, 'e2e_editor (category owner)', '#38495e')
  const { page } = user
  const adminCtx = await browser.newContext()
  const admin = await adminCtx.newPage()
  const title = `My reading list ${Date.now().toString(36)}`
  let cat

  const cleanup = async () => {
    if (cat) await admin.request.post(`/api/nodes/${cat}/action/delete`).catch(() => {})
    await adminCtx.close()
  }

  await demo.scenario('categories', [user], async () => {
    await Promise.all([loginAsE2EEditor(page), loginAsE2EAdmin(admin)])

    // Setup: the category, and two e2nodes to put in it (the first through the API).
    const created = await (await page.request.post('/api/category/create', { data: { title } })).json()
    expect(created.success).toBeTruthy()
    cat = created.node_id
    const lookup = async (t) => {
      const n = await (await page.request.get(`/api/nodes/lookup/e2node/${encodeURIComponent(t)}`)).json()
      expect(n && n.node_id, `seeded e2node "${t}"`).toBeTruthy()
      return { node_id: n.node_id, title: n.title || t }
    }
    const first = await lookup('cupping protocols and evaluation')
    const second = await lookup('historical origins of the beverage')
    const third = await lookup('quantum cryptography protocols')
    for (const n of [first, third]) {
      const added = await (await page.request.post('/api/category/add_member', { data: { category_id: cat, node_id: n.node_id } })).json()
      expect(added.success).toBeTruthy()
    }

    // 1. Add the second node from its page.
    await page.goto(`/node/${second.node_id}`)
    await demo.step(page, `opens "${second.title}"`)
    await demo.click(page.locator('button[title="Add to category"]').first())
    const select = page.locator('.modal-compact__select')
    await expect(select.locator(`option[value="${cat}"]`)).toHaveCount(1, { timeout: 10000 })
    await demo.step(page, `adds it to "${title}"`)
    await select.selectOption(String(cat))
    const add = page.waitForResponse((r) => r.url().includes('/api/category/add_member'))
    await demo.click(page.locator('.modal-compact__btn', { hasText: 'Add to Category' }))
    expect((await (await add).json()).success).toBeTruthy()

    // 2. Edit the category: remove the first member, save the order.
    await page.goto(`/node/${cat}?displaytype=edit`)
    await demo.step(page, 'opens the category to edit it')
    const items = page.locator('.category-edit__member-item')
    await expect(items).toHaveCount(3, { timeout: 10000 })
    const firstItem = items.filter({ hasText: first.title }).first()
    const removed = page.waitForResponse((r) => r.url().includes('/api/category/remove_member'))
    await demo.step(page, `removes "${first.title}"`)
    // Removing asks with the browser's own confirm dialog (#4096 replaces these); say OK.
    page.once('dialog', (dialog) => dialog.accept())
    await demo.click(firstItem.locator('button[title="Remove from category"]'))
    expect((await (await removed).json()).success).toBeTruthy()
    await expect(items).toHaveCount(2, { timeout: 10000 })

    // Move the bottom member to the top with the keyboard (dnd-kit: Space, ArrowUp, Space).
    const before = (await items.allTextContents()).map((t) => t.trim())
    const bottomTitle = before[1].includes(second.title) ? second.title : third.title
    const topTitle = bottomTitle === second.title ? third.title : second.title
    await demo.step(page, `moves "${bottomTitle}" to the top`)
    // The whole row is the drag handle; dnd-kit measures layout between keys, so pace them.
    await items.nth(1).focus()
    for (const key of ['Space', 'ArrowUp', 'Space']) {
      await page.keyboard.press(key)
      await page.waitForTimeout(250)
    }
    await expect(items.first()).toContainText(bottomTitle, { timeout: 5000 })
    const saved = page.waitForResponse((r) => r.url().includes('/api/category/reorder_members'))
    await demo.step(page, 'saves the order')
    await demo.click(page.locator('.category-edit__save-settings-btn', { hasText: 'Save Order' }))
    expect((await (await saved).json()).success).toBeTruthy()

    // 3. The category page lists what's left.
    await page.goto(`/node/${cat}`)
    const members = page.locator('.category-display__members-section')
    await expect(members).toContainText(topTitle, { timeout: 10000 })
    await expect(members).not.toContainText(first.title)
    const text = await members.innerText()
    expect(text.indexOf(bottomTitle), 'saved order: the moved member comes first').toBeLessThan(text.indexOf(topTitle))
    await demo.step(page, 'the category lists what is left, in the new order')
    await demo.show(members, 2500)

    // 4. An old ?displaytype= link still shows the node page.
    await page.goto(`/node/${second.node_id}?displaytype=printable`)
    await expect(page.locator('#e2-react-page-root')).toBeVisible()
    await expect(page.locator('h1').first()).toContainText(second.title)
    await demo.step(page, 'an old ?displaytype=printable link still shows the page')
    await demo.show(page.locator('h1').first(), 2000)
  }, { cleanup })
})
