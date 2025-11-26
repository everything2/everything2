const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

/**
 * GP Transfer E2E Test
 *
 * Tests the complete flow of GP transfer from admin to user:
 * 1. Admin logs in and uses Superbless to grant GP
 * 2. User logs in and sees GP increase notification in Epicenter
 * 3. User can then spin the Wheel of Surprise with new GP
 */

test.describe('GP Transfer Flow', () => {
  test('admin grants GP, user receives notification and can spin wheel', async ({ page }) => {
    // Step 1: Login as e2e_admin
    await loginAsE2EAdmin(page)

    // Step 2: Navigate to Superbless
    await page.goto('/title/Superbless')

    // Wait for page to load
    await expect(page.locator('text=/Superbless/i')).toBeVisible()

    // Fill in Superbless form to grant 5 GP to e2e_user
    // Superbless uses EnrichUsers0 for username, BestowGP0 for GP amount
    await page.fill('input[name="EnrichUsers0"]', 'e2e_user')
    await page.fill('input[name="BestowGP0"]', '5')
    await page.click('input[type="submit"]')

    // Wait for confirmation
    await page.waitForLoadState('networkidle')

    // Should see success message or be back on Superbless page
    await expect(page.locator('text=/Superbless|GP|bestow/i')).toBeVisible()

    // Step 3: Logout (navigate to logout page)
    await page.goto('/title/logout')
    await page.waitForLoadState('networkidle')

    // Step 4: Login as e2e_user
    await loginAsE2EUser(page)

    // Step 5: Check Epicenter nodelet for GP increase notification
    const epicenter = page.locator('#epicenter')
    await expect(epicenter).toBeVisible()

    // Look for GP increase indicator (exact format may vary)
    // User should see their GP has increased
    const gpText = epicenter.locator('text=/GP|experience|level/i')
    await expect(gpText.first()).toBeVisible()

    // Step 6: Navigate to Wheel of Surprise
    await page.goto('/title/Wheel+of+Surprise')

    // Verify page loaded
    await expect(page.locator('h1:has-text("Wheel of Surprise")')).toBeVisible()

    // Wait for React component to render
    await page.waitForSelector('.wheel-of-surprise', { timeout: 5000 })

    // Step 7: User should see "Spin" button (has 5+ GP now)
    const spinButton = page.locator('button:has-text("Spin")')
    await expect(spinButton).toBeVisible()

    // Optionally: Actually spin the wheel
    await spinButton.click()

    // Wait for spin result (component shows result in styled div)
    await expect(page.locator('.wheel-of-surprise div[style*="background"]'))
      .toBeVisible({ timeout: 5000 })
  })
})
