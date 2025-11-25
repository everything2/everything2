const { test, expect } = require('@playwright/test')
const { loginAsRoot, visitAsGuest } = require('./fixtures/auth')

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

    // Fill in Sign In nodelet
    await page.fill('#signin_user', 'root')
    await page.fill('#signin_passwd', 'blah')
    await page.click('input[type="submit"][value="Login"]')

    // Should show user is logged in
    await page.waitForLoadState('networkidle')
    await expect(page.locator('text=root')).toBeVisible()
  })

  test('chatterbox appears on homepage for logged-in users', async ({ page }) => {
    await loginAsRoot(page)

    // Chatterbox should be visible
    await expect(page.locator('#chatterbox')).toBeVisible()

    // Message input should be present
    await expect(page.locator('#message')).toBeVisible()
  })

  test('React page content loads', async ({ page }) => {
    await loginAsRoot(page)

    // Navigate to a React page (Wheel of Surprise)
    await page.goto('/title/Wheel+of+Surprise')

    // Verify React content rendered
    await expect(page.locator('text=Wheel of Surprise')).toBeVisible()
    await expect(page.locator('button:has-text("Spin the Wheel")')).toBeVisible()
  })

  test('Mason2 pages still work', async ({ page }) => {
    await loginAsRoot(page)

    // Navigate to a Mason2 page (search)
    await page.goto('/title/Everything+User+Search')

    // Verify page rendered
    await expect(page.locator('text=/search/i')).toBeVisible()
  })

  test('sidebar nodelets render', async ({ page }) => {
    await loginAsRoot(page)

    // Check for key nodelets
    const sidebar = page.locator('#sidebar')
    await expect(sidebar).toBeVisible()

    // At least chatterbox should be present
    await expect(sidebar.locator('#chatterbox')).toBeVisible()
  })
})
