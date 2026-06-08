const { test, expect } = require('@playwright/test')

/**
 * E2E Test User Login Tests
 *
 * Verifies all E2E test users can login successfully.
 * These users are created by tools/seeds.pl during database initialization.
 * All E2E users have password "test123".
 */

test.describe('E2E Test Users', () => {
  const e2eUsers = [
    { username: 'e2e_admin', role: 'Admin (e2gods)', gp: 500 },
    { username: 'e2e_editor', role: 'Editor (Content Editors)', gp: 300 },
    { username: 'e2e_developer', role: 'Developer (edev)', gp: 200 },
    { username: 'e2e_chanop', role: 'Chanop (chanops)', gp: 150 },
    { username: 'e2e_user', role: 'Regular user', gp: 100 },
    { username: 'e2e user space', role: 'User with space', gp: 75 }
  ]

  e2eUsers.forEach(({ username, role, gp }) => {
    test(`${username} (${role}) can login`, async ({ page }) => {
      await page.goto('/')

      // Expand Sign In nodelet if collapsed
      const signInHeader = page.locator('h2:has-text("Sign In")')
      const isCollapsed = await signInHeader.evaluate(el =>
        el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
      )
      if (isCollapsed) {
        await signInHeader.click()
        await page.waitForTimeout(300) // Wait for expand animation
      }

      // Fill in credentials
      await page.fill('#signin_user', username)
      await page.fill('#signin_passwd', 'test123')

      // Click and wait for JavaScript redirect
      await page.click('#sign_in button[type="submit"]')

      // Wait for React to render - epicenter nodelet is always visible for logged-in users
      await page.waitForSelector('#epicenter', { timeout: 10000 })

      // Verify login success - epicenter should contain "Log Out" link
      await expect(page.locator('#epicenter')).toContainText('Log Out')

      // User's homenode link should be visible in Epicenter
      // Handle spaces in username for URL encoding
      const usernameEncoded = username.replace(/ /g, '+')
      await expect(page.locator('#epicenter')).toContainText(username)
    })
  })

  test('e2e_admin has admin privileges', async ({ page }) => {
    await page.goto('/')

    // Login as e2e_admin
    const signInHeader = page.locator('h2:has-text("Sign In")')
    const isCollapsed = await signInHeader.evaluate(el =>
      el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
    )
    if (isCollapsed) {
      await signInHeader.click()
      await page.waitForTimeout(300)
    }

    await page.fill('#signin_user', 'e2e_admin')
    await page.fill('#signin_passwd', 'test123')

    // Click and wait for JavaScript redirect (like the successful login tests)
    await page.click('#sign_in button[type="submit"]')

    // Wait for React to render - epicenter nodelet is always visible for logged-in users
    await page.waitForSelector('#epicenter', { timeout: 10000 })

    // Navigate to admin page (e.g., Master Control)
    await page.goto('/title/Master+Control')
    await page.waitForLoadState('load')

    // Wait for React sidebar to render - need to wait for the #e2-react-page-root inside sidebar
    await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })

    // Admin privilege is authoritatively reflected in the bootstrap user object.
    // NB: the #master_control *nodelet* is a per-user SIDEBAR-CONFIG artifact, not
    // an admin signal -- a non-admin can have it in their nodelet order and an
    // admin can lack it -- so nodelet presence is not a valid privilege check.
    await page.waitForFunction(() => window.e2 && window.e2.user, { timeout: 10000 })
    const isAdmin = await page.evaluate(() => window.e2.user.admin === true)
    expect(isAdmin, 'e2e_admin should have admin=true in the bootstrap').toBe(true)
  })

  test('e2e_editor has editor privileges', async ({ page }) => {
    await page.goto('/')

    // Login as e2e_editor
    const signInHeader = page.locator('h2:has-text("Sign In")')
    const isCollapsed = await signInHeader.evaluate(el =>
      el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
    )
    if (isCollapsed) {
      await signInHeader.click()
      await page.waitForTimeout(300)
    }

    await page.fill('#signin_user', 'e2e_editor')
    await page.fill('#signin_passwd', 'test123')
    await page.click('#sign_in button[type="submit"]')
    await page.waitForLoadState('load')

    // Editors should be able to access editor features
    // This is a placeholder - add specific editor feature tests as needed
    await expect(page.locator('#chatterbox')).toBeVisible()
  })

  test('e2e_user has no special privileges', async ({ page }) => {
    await page.goto('/')

    // Login as e2e_user
    const signInHeader = page.locator('h2:has-text("Sign In")')
    const isCollapsed = await signInHeader.evaluate(el =>
      el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
    )
    if (isCollapsed) {
      await signInHeader.click()
      await page.waitForTimeout(300)
    }

    await page.fill('#signin_user', 'e2e_user')
    await page.fill('#signin_passwd', 'test123')
    await page.click('#sign_in button[type="submit"]')
    await page.waitForLoadState('load')

    // Regular user should see chatterbox
    await expect(page.locator('#chatterbox')).toBeVisible()

    // Navigate to Master Control - should NOT be accessible
    await page.goto('/title/Master+Control')

    // Authoritative privilege check via the bootstrap user object (see the admin
    // test above for why #master_control nodelet presence is NOT a valid signal).
    await page.waitForFunction(() => window.e2 && window.e2.user, { timeout: 10000 })
    const isAdmin = await page.evaluate(() => window.e2.user.admin === true)
    expect(isAdmin, 'e2e_user must not have admin').toBe(false)
  })
})
