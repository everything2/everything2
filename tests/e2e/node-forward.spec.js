const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * node_forward is E2's HTTP-redirect nodetype: visiting one 303s (See Other) to
 * its target. Server logic lives in Everything::Controller::node_forward
 * (migrated from Everything::Delegation::htmlpage) and was previously untested.
 *
 * Seeded fixtures (tools/seeds.pl):
 *   "Goto potato"  -> doctext = the "potato" e2node   (a GOOD forward)
 *   "Goto nowhere" -> doctext = "999999999"           (a DEAD target)
 *
 * Branch matrix:
 *   good link            -> forward ALL users to the target (sets originalTitle)
 *   bad link (non-admin) -> search page (match_all=1)   [circular OR dead target]
 *   bad link (admin)     -> the node's edit page (displaytype=edit)
 *
 * We assert against the raw 303 + Location header with maxRedirects:0 so the
 * redirect itself is the thing under test (same pattern as concurrent-isolation).
 */
test.describe('node_forward (HTTP redirect class)', () => {
  test('good forward 303s all users to the target node', async ({ request }) => {
    const r = await request.get('/title/Goto%20potato', { maxRedirects: 0 })
    expect(r.status()).toBe(303)
    const loc = r.headers()['location']
    expect(loc, 'Location header present').toBeTruthy()
    expect(loc, 'forward branch carries originalTitle').toMatch(/originalTitle/)
    expect(loc, 'not the search fallback').not.toMatch(/match_all/)
    expect(loc, 'not the edit fallback').not.toMatch(/displaytype=edit/)
  })

  test('circular link sends a non-admin to search', async ({ request }) => {
    // originalTitle == the node's own title -> circularLink -> badLink
    const r = await request.get('/title/Goto%20potato?originalTitle=Goto%20potato', { maxRedirects: 0 })
    expect(r.status()).toBe(303)
    expect(r.headers()['location'], 'circular -> search').toMatch(/match_all/)
  })

  test('dead target sends a non-admin to search', async ({ request }) => {
    const r = await request.get('/title/Goto%20nowhere', { maxRedirects: 0 })
    expect(r.status()).toBe(303)
    expect(r.headers()['location'], 'dead target -> search').toMatch(/match_all/)
  })

  // Both admin paths share a single login: the full UI login is the slow part of
  // these request-level checks (the post-login page pulls ad scripts that keep the
  // network busy), and two separate logins flirted with the 30s test timeout.
  test('admin sees edit on a bad link but is still forwarded on a good link', async ({ browser }) => {
    test.setTimeout(60000)
    const ctx = await browser.newContext()
    try {
      const page = await ctx.newPage()
      await loginAsE2EAdmin(page)

      // bad link -> the node's own edit page
      const bad = await page.request.get('/title/Goto%20nowhere', { maxRedirects: 0 })
      expect(bad.status()).toBe(303)
      expect(bad.headers()['location'], 'admin + bad link -> edit').toMatch(/displaytype=edit/)

      // good link -> a normal forward (admins aren't special-cased on good links)
      const good = await page.request.get('/title/Goto%20potato', { maxRedirects: 0 })
      expect(good.status()).toBe(303)
      const loc = good.headers()['location']
      expect(loc, 'admin good link still forwards').toMatch(/originalTitle/)
      expect(loc, 'admin good link is not an edit redirect').not.toMatch(/displaytype=edit/)
    } finally {
      await ctx.close()
    }
  })
})
