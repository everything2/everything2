const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Mini Messages E2E Tests
 *
 * Tests the Mini Messages feature in Chatterbox:
 * - Initial messages loaded from window.e2 (no API call)
 * - XOR display logic (mini messages vs Messages nodelet)
 * - Visibility based on user nodelet configuration
 *
 * CLEANUP STRATEGY:
 * - Read-only tests - no state changes
 * - No persistent modifications to user or messages
 * - Tests only verify display logic, not message CRUD
 *
 * TEST USER:
 * - e2e_admin (admin privileges, password: test123)
 * - Has default nodelets configured (includes Messages nodelet)
 */

test.describe('Mini Messages', () => {
  /**
   * Test: Initial messages load without API call
   *
   * Purpose: Verify that mini messages are hydrated from window.e2 data
   * on page load, avoiding unnecessary API roundtrip.
   *
   * Steps:
   * 1. Track all API calls to /api/messages/
   * 2. Login and navigate to home
   * 3. Check if mini messages visible
   * 4. If visible, verify NO API calls were made
   * 5. Verify "Recent Messages" heading appears
   *
   * Note: Mini messages only show when Messages nodelet is NOT in sidebar.
   * e2e_admin typically has Messages nodelet, so mini messages may not appear.
   *
   * Cleanup: N/A (read-only test)
   */
  test('loads initial messages on page load without API call', async ({ page }) => {
    // Track API calls
    const apiCalls = []
    page.on('request', req => {
      if (req.url().includes('/api/messages/')) {
        apiCalls.push({
          url: req.url(),
          method: req.method()
        })
      }
    })

    // Login and navigate to home
    await loginAsE2EAdmin(page)

    // Check if mini messages section exists (only if Messages nodelet not in sidebar)
    const miniMessages = page.locator('#chatterbox_messages')

    // If mini messages are visible, verify no API call was made on initial load
    if (await miniMessages.isVisible({ timeout: 2000 }).catch(() => false)) {
      // Should have loaded from initial page data (window.e2)
      expect(apiCalls.length).toBe(0)

      // Verify messages are displayed
      await expect(miniMessages.locator('text=Recent Messages')).toBeVisible()
    }
  })

  /**
   * Test: Mini messages XOR Messages nodelet visibility
   *
   * Purpose: Verify that mini messages and Messages nodelet are mutually
   * exclusive - only one should be visible at any time.
   *
   * Steps:
   * 1. Login as e2e_admin
   * 2. Check if mini messages visible
   * 3. Check if Messages nodelet visible
   * 4. Verify exactly one is visible (XOR logic)
   *
   * Rationale: If user has Messages nodelet in sidebar, they don't need
   * mini messages in chatterbox. Mini messages serve as fallback for users
   * who removed Messages nodelet from their sidebar.
   *
   * Cleanup: N/A (read-only test)
   */
  test('mini messages only show when Messages nodelet not in sidebar', async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Wait for React to hydrate
    await page.waitForSelector('#e2-react-root', { timeout: 5000 })

    const miniMessages = page.locator('#chatterbox_messages')
    const messagesNodelet = page.locator('#messages') // Messages nodelet ID (React component)

    // Either mini messages show OR Messages nodelet shows, never both
    const miniVisible = await miniMessages.isVisible({ timeout: 1000 }).catch(() => false)
    const nodeletVisible = await messagesNodelet.isVisible({ timeout: 1000 }).catch(() => false)

    // Exactly one should be visible (XOR)
    expect(miniVisible !== nodeletVisible).toBe(true)
  })
})
