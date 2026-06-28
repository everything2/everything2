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

/**
 * Guest gating (#4390 batch 3): is_guest was removed from page contentData; components read
 * user.guest from the global e2.user prop. A guest viewer sees the guest-only message; a
 * logged-in viewer does not. A fresh Playwright context has no session, so it IS a guest.
 * Each guestText is the exact string the dedup'd component renders only for guests.
 */
const GUEST_PAGES = [
  { name: 'between_the_cracks',    id: 1927770, guestText: 'fall between the cracks yourself' },
  { name: 'random_nodeshells',    id: 1802702, guestText: 'If you logged in' },
  { name: 'usergroup_discussions', id: 1977025, guestText: 'strike up long-winded conversations' },
  { name: 'the_catwalk',          id: 1854411, guestText: 'customize your view of the site if you sign up' },
  // noding_speedometer: not dedup'd, but it had the $APP->isGuest($USER) blessed-arg bug — a
  // guest was mis-detected as a member. This asserts the guest now gets the members-only notice
  // (would fail before the #4390 isGuest fix, when the guest wrongly got the speedometer form).
  { name: 'noding_speedometer',   id: 1206744, guestText: 'only registered members' },
]

test.describe('#4390 guest-gating reads from e2.user.guest (post-dedup)', () => {
  for (const p of GUEST_PAGES) {
    test(`${p.name}: a guest sees the guest-only message`, async ({ page }) => {
      // fresh context = no session = guest
      await page.goto(`/node/${p.id}`)
      await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })
      await expect(page.locator('body')).toContainText(p.guestText, { timeout: 10000 })
    })

    test(`${p.name}: a logged-in user does NOT see the guest-only message`, async ({ page }) => {
      await loginAsE2EUser(page)
      await page.goto(`/node/${p.id}`)
      await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })
      await page.waitForTimeout(2500)
      await expect(page.locator('body')).not.toContainText(p.guestText)
    })
  }
})
