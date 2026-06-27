const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

/**
 * #4390 contentData-global-dedup — end-to-end role gating.
 *
 * The viewer's role flags (is_admin/isAdmin/…) were removed from each page's contentData;
 * the React Document components now read them from the global `e2.user` prop (produced by
 * Everything::PageState::_build_user). These tests prove that, with the duplicate bytes gone,
 * the admin-only UI is still correctly gated by the REAL e2.user end-to-end: an admin sees the
 * admin control, a regular user does not. Pure jest can't catch a producer/consumer field-name
 * mismatch (e.g. user.admin vs user.is_admin) — this does.
 *
 * Each page's adminText is the exact string the dedup'd component renders only for admins
 * (reported by the per-page migration).
 */
const ADMIN_PAGES = [
  { name: 'recalculate_xp',      id: 1959368, adminText: 'Admin: Look up another user' },
  { name: 'my_big_writeup_list', id: 1490171, adminText: 'Search for user:' },
  { name: 'golden_trinkets',     id: 737456,  adminText: 'Admin Lookup' },
]

test.describe('#4390 role-gating reads from e2.user (post-dedup)', () => {
  for (const p of ADMIN_PAGES) {
    test(`${p.name}: admin sees the admin-only control`, async ({ page }) => {
      await loginAsE2EAdmin(page)
      await page.goto(`/node/${p.id}`)
      await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })
      // positive assertion auto-retries until the Document renders
      await expect(page.locator('body')).toContainText(p.adminText, { timeout: 10000 })
    })

    test(`${p.name}: regular user does NOT see the admin-only control`, async ({ page }) => {
      await loginAsE2EUser(page)
      await page.goto(`/node/${p.id}`)
      await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })
      // let the Document fully render before asserting the admin control is absent
      await page.waitForTimeout(2500)
      await expect(page.locator('body')).not.toContainText(p.adminText)
    })
  }
})
