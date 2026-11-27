const { test, expect } = require('@playwright/test')
const { loginAs } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Every page with a rich-text editor loads, with its content, for an ordinary member (#4639).
 *
 * TipTap's useEditor can hand a page an editor it has already destroyed: it schedules a 1ms
 * "destroy unless mounted" timer at first render, and when that fires before React runs the
 * page's effects (which the dev build does every time), the first effects see the destroyed
 * instance. Loading content into it throws, and React then unmounts the whole page, leaving
 * it blank. So each page here must load without an uncaught error, not blank, with its editor
 * showing what it should.
 *
 * User: normaluser4 (pw "blah", has a homenode bio; no other spec signs in as them). Setup: a
 * draft through the API, deleted afterwards.
 * Watch: `./tools/e2e-demo.sh editor-pages-load` (E2E_DEMO_DEVICE=mobile too).
 */
test('a member opens every page with an editor and each one loads', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 120000)
  const member = await demo.actor(browser, 'normaluser4 (a member)', '#38495e')
  const { page } = member
  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
  const bio = 'Homenode text for normaluser4'
  let draftId

  const errors = []
  page.on('pageerror', e => errors.push(`${page.url()}: ${e.message}`))

  const cleanup = async () => {
    if (draftId) await page.request.delete(`/api/drafts/${draftId}`).catch(() => {})
  }

  // The page rendered (React didn't unmount it) and no uncaught error was thrown while loading.
  const loaded = async (what) => {
    await page.waitForLoadState('load')
    await page.waitForTimeout(1500) // let the first effects run
    const rootLength = await page.evaluate(() => document.querySelector('#e2-react-page-root')?.innerHTML.length || 0)
    expect(errors, `${what}: no uncaught errors`).toEqual([])
    expect(rootLength, `${what}: the page is not blank`).toBeGreaterThan(1000)
  }
  const editor = () => page.locator('.tiptap, .ProseMirror').first()

  await demo.scenario('editor-pages-load', [member], async () => {
    await loginAs(page, 'normaluser4', 'blah')
    const created = await (await page.request.post('/api/drafts', {
      data: { title: `Editor pages ${stamp}`, doctext: `<p>Draft text ${stamp}</p>` },
    })).json()
    expect(created.success).toBeTruthy()
    draftId = created.draft.node_id

    await demo.step(page, 'opens Settings (its profile editor loads their bio)')
    await page.goto('/title/Settings')
    await loaded('Settings')
    await demo.show(page.locator('h1').first())

    await demo.step(page, 'opens Edit Profile on their homenode')
    await page.goto('/user/normaluser4?displaytype=edit')
    await loaded('homenode edit')
    await expect(editor()).toContainText(bio, { timeout: 10000 })
    await demo.show(editor())

    await demo.step(page, 'opens the writeup editor (E2 Editor Beta)')
    await page.goto('/title/E2%20Editor%20Beta')
    await loaded('E2 Editor Beta')
    await expect(editor()).toBeVisible({ timeout: 10000 })
    await demo.show(editor())

    await demo.step(page, 'opens a draft and clicks Edit')
    await page.goto(`/node/${draftId}`)
    await loaded('draft page')
    await demo.click(page.locator('.draft-page__toolbar .e2-action-chip', { hasText: 'Edit' }))
    await expect(editor()).toContainText(`Draft text ${stamp}`, { timeout: 10000 })
    expect(errors, 'draft editor: no uncaught errors').toEqual([])
    await demo.show(editor())

    await demo.step(page, 'opens an e2node page (with its add-a-writeup editor)')
    await page.goto('/title/about%20nobody')
    await loaded('e2node page')
    await demo.show(page.locator('h1').first())

    await demo.step(page, 'opens Create Category')
    await page.goto('/title/Create%20Category')
    await loaded('Create Category')
    await demo.show(page.locator('h1').first())
  }, { cleanup })
})
