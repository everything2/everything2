const { test, expect } = require('@playwright/test')
const { loginAsE2EUser, loginAsE2EAdmin } = require('./fixtures/auth')
const { createWriteup } = require('./fixtures/content')
const demo = require('./fixtures/demo')

/**
 * Search excerpts read as plain text (#3893).
 *
 * A writeup that opens with HTML entities (a leading &nbsp;, curly quotes, a dash, &#93;&#91;,
 * &quot;, &amp;, &eacute;, as old and editor-made writeups do) should never show those
 * entities to a reader:
 *   - in the excerpt a guest sees on the search results page (Findings);
 *   - in the page's meta description, which is what search engines show as the excerpt
 *     (read the way a crawler reads it, decoded once).
 *
 * The writeup is published by e2e_user and removed by e2e_admin (both unrecorded).
 * Watch it: `./tools/e2e-demo.sh search-excerpts` (E2E_DEMO_DEVICE=mobile for phones).
 */
const DOCTEXT =
  '<p>&nbsp;</p><p>&ldquo;Quoted&rdquo; opening &mdash; the Apple &#93;&#91; was &quot;small&quot; &amp; caf&eacute;.</p>' +
  '<p>Second paragraph.</p>'
const PLAIN = '“Quoted” opening — the Apple ][ was "small" & café. Second paragraph.'
const ENTITY = /&(#\d+|#x[0-9a-f]+|[a-z]+);/i

test('search excerpts and the meta description show text, not HTML entities', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const word = `xcheck${Date.now().toString(36)}`
  const title = `Excerpt check ${word}`
  const guest = await demo.actor(browser, 'guest (searching)', '#38495e')
  const { page } = guest
  const authorCtx = await browser.newContext()
  const author = await authorCtx.newPage()
  const adminCtx = await browser.newContext()
  const admin = await adminCtx.newPage()
  let made

  const cleanup = async () => {
    if (made) {
      for (const id of [made.writeupId, made.e2nodeId]) {
        await admin.request.post(`/api/nodes/${id}/action/delete`).catch(() => {})
      }
    }
    await Promise.all([authorCtx.close(), adminCtx.close()])
  }

  await demo.scenario('search-excerpts', [guest], async () => {
    await Promise.all([loginAsE2EUser(author), loginAsE2EAdmin(admin)])
    made = await createWriteup(author, { title, doctext: DOCTEXT })
    await page.goto('/')
    await demo.note(guest, `e2e_user published "${title}"`,
      `Its text opens with entities, in a session that is not recorded:\n${DOCTEXT}`)

    // 1. The search results excerpt.
    await demo.step(page, `searches for "${word}"`)
    const search = page.locator('#searchform input[type="text"], #searchform input[type="search"]').first()
    await search.click()
    await search.fill(word)
    await search.press('Enter')
    const excerpt = page.locator('.findings-excerpt').first()
    await expect(excerpt).toHaveText(PLAIN, { timeout: 15000 })
    expect(await excerpt.textContent()).not.toMatch(ENTITY)
    await demo.step(page, 'the excerpt reads as plain text')
    await demo.show(excerpt, 2500)

    // 2. The meta description search engines read, decoded once as a crawler would.
    await demo.step(page, 'opens the result')
    await demo.click(page.locator('.findings-excerpt-link').first())
    await expect(page).toHaveTitle(new RegExp(word), { timeout: 15000 })
    const meta = await page.locator('meta[name="description"]').getAttribute('content')
    expect(meta).toBe(PLAIN)
    await demo.note(guest, 'reads the page\'s meta description (what search engines show)',
      `<meta name="description"> as a crawler reads it:\n${meta}`)
  }, { cleanup })
})
