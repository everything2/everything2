const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

/**
 * GP Transfer E2E Test
 *
 * Tests the complete flow of GP transfer from admin to user:
 * 1. Admin resets user GP to 0 via basicedit
 * 2. User logs in to set oldGP to 0
 * 3. Admin grants GP via Superbless
 * 4. User logs in and sees exact GP notification in Epicenter
 * 5. User can spin the Wheel of Surprise with granted GP
 *
 * CLEANUP STRATEGY:
 * - Test uses deterministic approach: reset GP → set oldGP → grant → verify exact amount
 * - Each run starts with e2e_user at 0 GP and oldGP = 0
 * - Grants exactly 5 GP via Superbless
 * - Verifies notification shows exactly "5 GP"
 *
 * TEST USERS:
 * - e2e_admin (admin, password: test123) - Manages GP cleanup and grants via Superbless
 * - e2e_user (regular user, password: test123) - Receives GP and spins wheel
 */

test.describe('GP Transfer Flow', () => {

  /**
   * Helper function to logout current user
   */
  async function logout(page) {
    const logoutLink = page.locator('#epicenter a[href*="logout"]').first()
    await logoutLink.click()
    await page.waitForLoadState('networkidle', { timeout: 10000 })

    // Wait for logout to complete - page should show guest user
    await page.waitForFunction(() => {
      return window.e2 && window.e2.user && window.e2.user.guest === true
    }, { timeout: 5000 })
  }

  /**
   * Helper function to reset e2e_user's GP to 0 via basicedit
   */
  async function resetUserGP(page) {
    // Navigate to e2e_user's basicedit page
    await page.goto('/user/e2e_user?displaytype=basicedit')

    // Wait for page to load
    await expect(page.locator('h1:has-text("e2e_user")')).toBeVisible()

    // Find GP field and scroll it into view
    const gpField = page.locator('input[name="update_GP"]')
    await gpField.scrollIntoViewIfNeeded()

    // Clear and set GP to 0
    await gpField.clear()
    await gpField.fill('0')

    // Submit the form
    await page.click('input[type="submit"][name="sexisgood"]')

    // Wait for page to reload
    await page.waitForLoadState('networkidle', { timeout: 10000 })
  }

  /**
   * Test: Complete GP transfer flow from admin to user with deterministic values
   *
   * Purpose: Verify that the Superbless → Epicenter notification → Wheel
   * workflow functions correctly with exact, predictable GP amounts.
   *
   * Steps:
   * 1. Login as e2e_admin
   * 2. Reset e2e_user's GP to 0 via basicedit
   * 3. Logout
   * 4. Login as e2e_user (sets oldGP to 0 in VARS)
   * 5. Logout
   * 6. Login as e2e_admin
   * 7. Grant exactly 5 GP to e2e_user via Superbless
   * 8. Logout
   * 9. Login as e2e_user
   * 10. Verify GP notification shows exactly "5 GP"
   * 11. Navigate to Wheel of Surprise
   * 12. Verify Spin button visible
   * 13. Spin wheel to demonstrate GP usage
   */
  test('admin grants GP, user receives notification and can spin wheel', async ({ page }) => {
    // Step 1: Login as e2e_admin
    await loginAsE2EAdmin(page)

    // Step 2: Reset e2e_user's GP to 0 via basicedit
    await resetUserGP(page)

    // Step 3: Logout
    await logout(page)

    // Step 4: Login as e2e_user to set oldGP to 0
    await loginAsE2EUser(page)

    // Step 5: Logout
    await logout(page)

    // Step 6: Login as e2e_admin again
    await loginAsE2EAdmin(page)

    // Step 7: Navigate to Superbless and grant 5 GP
    await page.goto('/title/Superbless')
    await expect(page.locator('h1:has-text("Superbless")')).toBeVisible()

    // Wait for React component to load
    await page.waitForSelector('#e2-react-page-root', { timeout: 5000 })

    // Fill in the first row of the React form (username and GP amount)
    const usernameInputs = page.locator('input[placeholder="Enter username"]')
    const gpInputs = page.locator('input[type="number"]')

    await usernameInputs.first().fill('e2e_user')
    await gpInputs.first().fill('5')

    // Submit the form
    await page.click('button:has-text("Superbless")')

    // Wait for results to appear
    await expect(page.locator('text=was given 5 GP')).toBeVisible({ timeout: 10000 })

    // Step 8: Logout
    await logout(page)

    // Step 9: Login as e2e_user
    await loginAsE2EUser(page)

    // Step 10: Verify GP notification shows exactly "5 GP"
    const epicenter = page.locator('#epicenter')
    await expect(epicenter).toBeVisible()

    const gpGainMessage = epicenter.locator('#gp')
    await expect(gpGainMessage).toBeVisible({ timeout: 5000 })

    // Since we reset GP to 0 and set oldGP to 0, we should see exactly 5 GP gained
    await expect(gpGainMessage).toContainText('Yay! You gained 5 GP!')

    // Step 11: Navigate to Wheel of Surprise
    await page.goto('/title/Wheel+of+Surprise')
    await expect(page.locator('h1:has-text("Wheel of Surprise")')).toBeVisible()

    // Wait for React component to render
    await page.waitForSelector('.wheel-of-surprise', { timeout: 5000 })

    // Step 12: Verify Spin button visible (user has 5+ GP now)
    const spinButton = page.locator('button:has-text("Spin")')
    await expect(spinButton).toBeVisible()

    // Step 13: Spin wheel to demonstrate user can use granted GP
    await spinButton.click()

    // Wait for spin result
    await expect(page.locator('.wheel-of-surprise div[style*="background"]'))
      .toBeVisible({ timeout: 5000 })

    // Test complete - e2e_user now has variable GP depending on wheel prize
  })
})
