/**
 * concurrent-isolation.spec.js
 *
 * Cross-request / cross-user isolation under the PERSISTENT-WORKER model.
 *
 * mod_perl and PSGI/Starman both keep Perl interpreters alive across requests,
 * so any request-scoped data parked in a package global, a CGI internal, or a
 * cache can bleed into the NEXT request on the same worker -- serving user A's
 * page to user B (data leak), or a stale logout cookie to the wrong session.
 * The mitigations live in app.psgi (CGI::initialize_globals per request) and
 * mod_perlInit (reassigns $query/$USER/$NODE/%HEADER_PARAMS at the top). This
 * suite is the behavioural net that proves they hold under concurrency.
 *
 * ============================ AUDIT PILE ============================
 * Vectors to cover (implemented ones are tests below; the rest are tracked
 * stubs so we don't forget them):
 *   [x] same personalized URL, two authed users hammered concurrently
 *   [x] guest vs authed concurrently on the same URL
 *   [x] concurrent canonical redirects for different nodes (no Location swap)
 *   [ ] CROSS-ENTRY-POINT: a page request and an /api request interleaved for
 *       different users -- API handlers don't run mod_perlInit, so a page global
 *       like $Everything::HTML::USER can be stale from a prior page request on
 *       the same worker (the hazard the Router.pm cookie comment guards). Needs
 *       an /api endpoint that echoes the authenticated identity.
 *   [ ] logout cookie isolation: one user logs out while another is mid-session
 *       on the same worker (the "random logout" class).
 * ===================================================================
 */

const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

// Read the authenticated identity out of the page bootstrap. We stringify the
// whole user object and check membership rather than guessing the field name,
// so the test is robust to bootstrap shape changes.
async function bootstrapUserBlob(page) {
  return page.evaluate(() => JSON.stringify((window.e2 && window.e2.user) || {}))
}

test.describe('Concurrent cross-user isolation', () => {
  test('same URL, two authed users hammered concurrently -> never crossed', async ({ browser }) => {
    const ctxA = await browser.newContext()
    const ctxB = await browser.newContext()
    const a = await ctxA.newPage()
    const b = await ctxB.newPage()
    await loginAsE2EAdmin(a)   // e2e_admin
    await loginAsE2EUser(b)    // e2e_user

    // Both reload the SAME personalized page (the homepage embeds the logged-in
    // user in window.e2.user) concurrently, many rounds. If a worker bleeds A's
    // render to B (or vice versa), the wrong username shows up.
    for (let round = 0; round < 12; round++) {
      await Promise.all([a.goto('/'), b.goto('/')])
      const [ua, ub] = await Promise.all([bootstrapUserBlob(a), bootstrapUserBlob(b)])
      expect(ua, `round ${round}: admin context must be e2e_admin`).toContain('e2e_admin')
      expect(ua, `round ${round}: admin context leaked e2e_user`).not.toContain('e2e_user')
      expect(ub, `round ${round}: user context must be e2e_user`).toContain('e2e_user')
      expect(ub, `round ${round}: user context leaked e2e_admin`).not.toContain('e2e_admin')
    }
    await ctxA.close(); await ctxB.close()
  })

  test('guest and authed user concurrently -> guest never sees authed content', async ({ browser }) => {
    const ctxG = await browser.newContext()
    const ctxA = await browser.newContext()
    const g = await ctxG.newPage()
    const a = await ctxA.newPage()
    await loginAsE2EAdmin(a)

    for (let round = 0; round < 12; round++) {
      await Promise.all([g.goto('/'), a.goto('/')])
      const [ug, ua] = await Promise.all([bootstrapUserBlob(g), bootstrapUserBlob(a)])
      // Guest bootstrap must be a guest (no e2e_admin identity bleeding in).
      expect(ug, `round ${round}: guest leaked e2e_admin`).not.toContain('e2e_admin')
      expect(ug, `round ${round}: guest should be guest`).toMatch(/"guest":true|Guest/i)
      expect(ua, `round ${round}: authed must stay e2e_admin`).toContain('e2e_admin')
    }
    await ctxG.close(); await ctxA.close()
  })

  test('concurrent canonical redirects for different nodes keep their own Location', async ({ request }) => {
    // Two e2nodes; by-id + lastnode_id each 303s to its OWN canonical /title/.
    // Fire them concurrently and assert no Location swap (the redirect is built
    // from a per-request CGI clone -- this proves that clone isn't shared state).
    const ids = { 'good+poetry': null, 'Sense': null }
    // discover ids via title pages
    const poetry = await request.get('/title/good%20poetry')
    const sense = await request.get('/title/Sense%20%26%20Sensibility')
    const pid = (await poetry.text()).match(/"node":\{[^}]*?"node_id":"?(\d+)"?/)?.[1]
    const sid = (await sense.text()).match(/"node":\{[^}]*?"node_id":"?(\d+)"?/)?.[1]
    expect(pid && sid, 'discovered both e2node ids').toBeTruthy()

    for (let round = 0; round < 10; round++) {
      const [rp, rs] = await Promise.all([
        request.get(`/?node_id=${pid}&lastnode_id=0`, { maxRedirects: 0 }),
        request.get(`/?node_id=${sid}&lastnode_id=0`, { maxRedirects: 0 }),
      ])
      expect(rp.status()).toBe(303)
      expect(rs.status()).toBe(303)
      expect(rp.headers()['location'], `round ${round}: poetry Location`).toMatch(/good\+poetry/)
      expect(rs.headers()['location'], `round ${round}: sense Location`).toMatch(/Sense/)
    }
  })
})
