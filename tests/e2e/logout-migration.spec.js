const { test, expect } = require('@playwright/test')
const { loginAsRoot } = require('./fixtures/auth')

/**
 * Validates the op=logout -> POST /api/sessions/delete migration (#4335 Phase 2).
 * A real browser logs in, clicks the migrated LogoutLink, and must end up back
 * at guest with the session cookie cleared by the server (not just client-side).
 */
test.describe('Logout migration (#4335 Phase 2)', () => {
  test('LogoutLink logs out via the sessions API and returns to guest', async ({ page }) => {
    await loginAsRoot(page)
    await page.waitForFunction(
      () => window.e2 && window.e2.user && window.e2.user.guest === false,
      { timeout: 10000 }
    )

    // Migrated LogoutLink: href='/', class 'logout-link', POSTs /api/sessions/delete
    await page.locator('a.logout-link').first().click()

    await page.waitForFunction(
      () => window.e2 && window.e2.user && window.e2.user.guest === true,
      { timeout: 10000 }
    )

    // Server-side clear: the session cookie should be gone (or emptied)
    const cookies = await page.context().cookies()
    const userpass = cookies.find((c) => c.name === 'userpass')
    expect(userpass === undefined || userpass.value === '').toBeTruthy()
  })
})
