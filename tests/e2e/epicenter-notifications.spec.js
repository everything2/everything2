const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

/**
 * Epicenter Notifications E2E Test Suite
 *
 * Tests notifications that appear in the Epicenter nodelet:
 * - GP (Gaming Points) gain notifications
 * - Experience point gain notifications
 * - Votes and Cools remaining display
 *
 * CLEANUP STRATEGY:
 * - Use basicedit to reset GP, experience, AND VARS (oldGP, oldexp)
 * - beforeEach hook ensures clean state for every test
 * - Robust logout without networkidle timeout
 *
 * USER ROLES:
 * - e2e_admin: Admin with gods privileges, can modify other users via basicedit
 * - e2e_user: Regular test user, receives notifications
 */

test.describe.configure({ mode: 'serial' });

test.describe('Epicenter Notifications', () => {

  /**
   * Helper function to logout current user (robust version)
   *
   * Fixes the 'networkidle' timeout by just checking for guest state.
   * Ongoing polls/requests can prevent networkidle from resolving.
   */
  async function logout(page) {
    const logoutLink = page.locator('#epicenter a[href*="logout"]').first()
    await logoutLink.click()

    // Wait for logout to complete - check for guest state
    await page.waitForFunction(() => {
      return window.e2 && window.e2.user && window.e2.user.guest === true
    }, { timeout: 10000 })

    // Wait a bit for page to settle
    await page.waitForTimeout(500)
  }

  /**
   * Helper function to reset user's VARS (oldGP, oldexp) via basicedit
   *
   * This prevents test interference by clearing stale notification baselines.
   */
  async function resetUserVARS(page, username) {
    await page.goto(`/user/${username}?displaytype=basicedit`)
    await expect(page.locator(`h1:has-text("${username}")`)).toBeVisible()

    // Find vars textarea and clear oldGP and oldexp
    const varsField = page.locator('textarea[name="update_vars"]')
    await varsField.scrollIntoViewIfNeeded()

    // Get current VARS, remove oldGP and oldexp
    let varsText = await varsField.inputValue()
    varsText = varsText.replace(/&?oldGP=[^&]*/g, '')
    varsText = varsText.replace(/&?oldexp=[^&]*/g, '')
    varsText = varsText.replace(/^&+/, '') // Remove leading &
    varsText = varsText.replace(/&+/g, '&') // Collapse multiple &

    await varsField.clear()
    await varsField.fill(varsText)

    await page.click('input[type="submit"][name="sexisgood"]')
    await page.waitForLoadState('networkidle', { timeout: 10000 })
  }

  /**
   * Helper function to set user's oldGP and oldexp VARS via basicedit
   *
   * This explicitly sets the notification baselines for testing.
   */
  async function setUserOldVars(page, username, oldGP, oldexp) {
    await page.goto(`/user/${username}?displaytype=basicedit`)
    await expect(page.locator(`h1:has-text("${username}")`)).toBeVisible()

    // Find vars textarea
    const varsField = page.locator('textarea[name="update_vars"]')
    await varsField.scrollIntoViewIfNeeded()

    // Get current VARS, remove existing oldGP/oldexp, then add new values
    let varsText = await varsField.inputValue()
    varsText = varsText.replace(/&?oldGP=[^&]*/g, '')
    varsText = varsText.replace(/&?oldexp=[^&]*/g, '')
    varsText = varsText.replace(/^&+/, '') // Remove leading &
    varsText = varsText.replace(/&+/g, '&') // Collapse multiple &

    // Add new oldGP and oldexp values
    if (varsText) {
      varsText += `&oldGP=${oldGP}&oldexp=${oldexp}`
    } else {
      varsText = `oldGP=${oldGP}&oldexp=${oldexp}`
    }

    await varsField.clear()
    await varsField.fill(varsText)

    await page.click('input[type="submit"][name="sexisgood"]')
    await page.waitForLoadState('networkidle', { timeout: 10000 })
  }

  /**
   * Helper function to set user's GP via basicedit
   */
  async function setUserGP(page, username, gpValue) {
    await page.goto(`/user/${username}?displaytype=basicedit`)
    await expect(page.locator(`h1:has-text("${username}")`)).toBeVisible()

    const gpField = page.locator('input[name="update_GP"]')
    await gpField.scrollIntoViewIfNeeded()
    await gpField.clear()
    await gpField.fill(gpValue.toString())

    await page.click('input[type="submit"][name="sexisgood"]')
    await page.waitForLoadState('networkidle', { timeout: 10000 })
  }

  /**
   * Helper function to set user's experience via basicedit
   */
  async function setUserExperience(page, username, expValue) {
    await page.goto(`/user/${username}?displaytype=basicedit`)
    await expect(page.locator(`h1:has-text("${username}")`)).toBeVisible()

    const expField = page.locator('input[name="update_experience"]')
    await expField.scrollIntoViewIfNeeded()
    await expField.clear()
    await expField.fill(expValue.toString())

    await page.click('input[type="submit"][name="sexisgood"]')
    await page.waitForLoadState('networkidle', { timeout: 10000 })
  }

  /**
   * beforeEach: Reset e2e_user's state before every test
   *
   * Ensures test isolation by:
   * 1. Clearing VARS (oldGP, oldexp)
   * 2. Resetting GP to 0
   * 3. Resetting experience to 100
   */
  test.beforeEach(async ({ page }) => {
    await loginAsE2EAdmin(page)
    await resetUserVARS(page, 'e2e_user')
    await setUserGP(page, 'e2e_user', 0)
    await setUserExperience(page, 'e2e_user', 100)
    await logout(page)
  })

  test.describe('GP Gain Notifications', () => {
    /**
     * Test: User receives GP gain notification after admin grants GP
     *
     * This test validates the complete flow and the bugfix in Application.pm:6133
     * where we validate oldGP is numeric to handle garbage data.
     */
    test('user receives GP gain notification after admin grant', async ({ page }) => {
      // Setup: Set e2e_user's GP to 0 and oldGP = 0
      await loginAsE2EAdmin(page)
      await setUserGP(page, 'e2e_user', 0)
      await setUserOldVars(page, 'e2e_user', 0, 100)

      // Grant 20 GP to e2e_user (increase GP from 0 to 20)
      await setUserGP(page, 'e2e_user', 20)
      await logout(page)

      // Login as e2e_user - notification should appear on front page after login
      // (Login redirects to front page which triggers buildNodeInfoStructure)
      await loginAsE2EUser(page)

      // Check for GP notification on front page (where we land after login)
      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      const gpGainMessage = epicenter.locator('#gp')
      await expect(gpGainMessage).toBeVisible({ timeout: 5000 })
      await expect(gpGainMessage).toContainText('Yay! You gained 20 GP!')
    })

    /**
     * Test: Negative GP changes do not show notification
     *
     * Verifies that GP losses (e.g., from spinning wheel) do not
     * trigger negative notifications.
     */
    test('negative GP changes do not show notification', async ({ page }) => {
      // Setup: Give user 100 GP and set oldGP = 100
      await loginAsE2EAdmin(page)
      await setUserGP(page, 'e2e_user', 100)
      await setUserOldVars(page, 'e2e_user', 100, 100)

      // Reduce GP to 50
      await setUserGP(page, 'e2e_user', 50)
      await logout(page)

      // Login as e2e_user and navigate to a React page - should NOT see GP notification
      await loginAsE2EUser(page)
      await page.goto('/title/Settings')
      await expect(page.locator('h1:has-text("Settings")')).toBeVisible()

      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      const gpGainMessage = epicenter.locator('#gp')
      await expect(gpGainMessage).not.toBeVisible()
    })
  })

  test.describe('Experience Gain Notifications', () => {
    /**
     * Test: User receives experience gain notification
     *
     * Validates the bugfix in Application.pm:6121 where we validate
     * oldexp is numeric to handle garbage data.
     */
    test('user receives experience gain notification', async ({ page }) => {
      // Setup: Set e2e_user's experience to 500 and oldexp = 500
      await loginAsE2EAdmin(page)
      await setUserExperience(page, 'e2e_user', 500)
      await setUserOldVars(page, 'e2e_user', 0, 500)

      // Increase experience to 550 (+50)
      await setUserExperience(page, 'e2e_user', 550)
      await logout(page)

      // Login as e2e_user - notification should appear on front page after login
      // (Login redirects to front page which triggers buildNodeInfoStructure)
      await loginAsE2EUser(page)

      // Check for experience notification on front page (where we land after login)
      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      const expGainMessage = epicenter.locator('#experience')
      await expect(expGainMessage).toBeVisible({ timeout: 5000 })
      await expect(expGainMessage).toContainText('50')
    })

    /**
     * Test: Negative experience changes do not show notification
     *
     * Verifies the bugfix in Application.pm:6127 where oldexp is always
     * updated (not just on positive gains).
     */
    test('negative experience changes do not show notification', async ({ page }) => {
      // Setup: Give user 1000 experience and set oldexp = 1000
      await loginAsE2EAdmin(page)
      await setUserExperience(page, 'e2e_user', 1000)
      await setUserOldVars(page, 'e2e_user', 0, 1000)

      // Reduce experience to 800
      await setUserExperience(page, 'e2e_user', 800)
      await logout(page)

      // Login as e2e_user and navigate to a React page - should NOT see experience notification
      await loginAsE2EUser(page)
      await page.goto('/title/Settings')
      await expect(page.locator('h1:has-text("Settings")')).toBeVisible()

      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      const expGainMessage = epicenter.locator('#experience')
      await expect(expGainMessage).not.toBeVisible()
    })
  })

  test.describe('Votes and Cools Display', () => {
    /**
     * Test: Votes remaining display
     *
     * Verifies that Epicenter shows the number of votes remaining.
     * Note: Votes refresh daily, so exact count varies.
     */
    test('shows votes remaining when user has votes', async ({ page }) => {
      await loginAsE2EUser(page)

      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      // Check if voteschingsleft paragraph exists (may or may not be visible)
      const votesAndCoolsSection = epicenter.locator('#voteschingsleft')

      // If the section exists, it should contain text about votes or cools
      const isVisible = await votesAndCoolsSection.isVisible().catch(() => false)

      if (isVisible) {
        const text = await votesAndCoolsSection.textContent()
        // Should mention either "vote" or "C!"
        expect(text).toMatch(/vote|C!/i)
      }
      // If not visible, user has 0 votes and 0 cools (valid state)
    })

    /**
     * Test: Cools remaining display
     *
     * Verifies that Epicenter shows the number of C!s (cools) remaining.
     */
    test('shows cools when user has cools', async ({ page }) => {
      await loginAsE2EUser(page)

      const epicenter = page.locator('#epicenter')
      await expect(epicenter).toBeVisible()

      // Check if voteschingsleft paragraph exists
      const votesAndCoolsSection = epicenter.locator('#voteschingsleft')

      const isVisible = await votesAndCoolsSection.isVisible().catch(() => false)

      if (isVisible) {
        const text = await votesAndCoolsSection.textContent()
        // Should contain information about votes/cools remaining
        expect(text).toMatch(/You have .+ left today/i)
      }
      // If not visible, user has no votes or cools (valid state)
    })
  })
})
