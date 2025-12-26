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
      await Promise.all([
        page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
        page.click('input[type="submit"]')
      ])

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
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
      page.click('input[type="submit"]')
    ])

    // Wait for React to render - epicenter nodelet is always visible for logged-in users
    await page.waitForSelector('#epicenter', { timeout: 10000 })

    // Navigate to admin page (e.g., Master Control)
    await page.goto('/title/Master+Control')
    await page.waitForLoadState('networkidle')

    // Wait for React sidebar to render - need to wait for the #e2-react-root inside sidebar
    await page.waitForSelector('#sidebar #e2-react-root', { timeout: 10000 })

    // Admin users should see Master Control nodelet
    await expect(page.locator('#master_control')).toBeVisible({ timeout: 10000 })

    // Should see admin-specific features (node notes section is always visible in Master Control)
    await expect(page.locator('#nodenotes')).toBeVisible()
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
    await page.click('input[type="submit"][value="Login"]')
    await page.waitForLoadState('networkidle')

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
    await page.click('input[type="submit"][value="Login"]')
    await page.waitForLoadState('networkidle')

    // Regular user should see chatterbox
    await expect(page.locator('#chatterbox')).toBeVisible()

    // Navigate to Master Control - should NOT be accessible
    await page.goto('/title/Master+Control')

    // Should not see Master Control nodelet (redirected or permission denied)
    const masterControl = page.locator('#master_control')
    const isVisible = await masterControl.isVisible().catch(() => false)
    expect(isVisible).toBe(false)
  })
})
