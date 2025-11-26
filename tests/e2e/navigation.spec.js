const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, visitAsGuest } = require('./fixtures/auth')

test.describe('Navigation & Basic Functionality', () => {
  test('homepage loads for guests', async ({ page }) => {
    await visitAsGuest(page)

    // Verify Sign In nodelet is present
    await expect(page.locator('#signin_user')).toBeVisible()
    await expect(page.locator('#signin_passwd')).toBeVisible()
  })

  test('login flow works', async ({ page }) => {
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

    // Fill in Sign In nodelet with e2e_admin credentials
    await page.fill('#signin_user', 'e2e_admin')
    await page.fill('#signin_passwd', 'test123')
    await page.click('input[type="submit"][value="Login"]')

    // Should show user is logged in - verify Sign In nodelet is gone (replaced with user info)
    await page.waitForLoadState('networkidle')
    await expect(page.locator('#signin_user')).not.toBeVisible()

    // User's homenode link should be visible in Epicenter
    await expect(page.locator('#epicenter')).toContainText('e2e_admin')
  })

  test('Mason2 pages still work', async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Navigate to a Mason2 page (search)
    await page.goto('/title/Everything+User+Search')

    // Verify page rendered - use specific heading instead of ambiguous "search" text
    await expect(page.locator('h1:has-text("Everything User Search")')).toBeVisible()
  })

  test('sidebar renders for logged-in users', async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Check that sidebar div exists and renders
    const sidebar = page.locator('#sidebar')
    await expect(sidebar).toBeVisible()

    // Verify at least one nodelet is rendered (user has configured nodelets)
    const nodelets = sidebar.locator('[id*="nodelet"], [class*="nodelet"]')
    await expect(nodelets.first()).toBeVisible()
  })

  test('about nobody page loads for guests', async ({ page }) => {
    await visitAsGuest(page)

    // Navigate to "about nobody" page
    await page.goto('/title/about+nobody')

    // Verify page contains "Andrew Lang" text
    await expect(page.locator('text=Andrew Lang')).toBeVisible()
  })
})
