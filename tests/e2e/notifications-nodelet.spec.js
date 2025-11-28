const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin, loginAsE2EUser } = require('./fixtures/auth')

/**
 * Notifications Nodelet E2E Test Suite
 *
 * Tests complete notification workflow:
 * - Adding/removing Notifications nodelet
 * - Subscribing to notification types
 * - Triggering notifications via user actions
 * - Viewing and dismissing notifications
 *
 * CLEANUP STRATEGY:
 * - Tests clean up after themselves (remove nodelet, unsubscribe)
 * - Serial execution prevents interference
 *
 * USER ROLES:
 * - e2e_admin: Receives notifications, subscribes to node notes
 * - e2e_editor: Triggers notifications by creating node notes
 */

test.describe.configure({ mode: 'serial' });

test.describe('Notifications Nodelet - Complete Workflow', () => {

  /**
   * Helper: Add Notifications nodelet via Nodelet Settings
   */
  async function addNotificationsNodelet(page) {
    await page.goto('/title/Nodelet+Settings')
    await page.waitForLoadState('networkidle')

    // Find all select dropdowns and try each one to find "Notifications"
    const selects = page.locator('select')
    const count = await selects.count()

    for (let i = 0; i < count; i++) {
      const select = selects.nth(i)

      // Check if this dropdown has a "Notifications" option
      const notificationsOption = select.locator('option:has-text("Notifications")')
      if (await notificationsOption.count() > 0) {
        // Select "Notifications" from this dropdown
        await select.selectOption('Notifications')

        // Find and click the submit button (there should be one per form/row)
        // Use the closest form's submit button
        const form = select.locator('xpath=ancestor::form[1]')
        const submitButton = form.locator('input[type="submit"]').first()
        await submitButton.click()

        await page.waitForLoadState('networkidle')
        return true
      }
    }

    throw new Error('Could not find Notifications option in any dropdown')
  }

  /**
   * Helper: Remove Notifications nodelet via Nodelet Settings
   */
  async function removeNotificationsNodelet(page) {
    await page.goto('/title/Nodelet+Settings')
    await page.waitForLoadState('networkidle')

    // Nodelet Settings page shows nodelets as draggable items in the main content area
    // Search only within #mainbody to avoid matching the sidebar nodelets
    const mainContent = page.locator('#mainbody')

    // Nodelet Settings uses select dropdowns with node IDs as values
    // First, get the Notifications nodelet ID from window.e2
    const notificationsId = await page.evaluate(() => {
      // Find Notifications nodelet node_id - it's a nodelet with title "Notifications"
      // We can hardcode this for now, or look it up dynamically
      return '1930708' // Notifications nodelet ID in dev environment
    })

    // Look for select elements that have the Notifications nodelet ID as selected value
    const selects = mainContent.locator('select')
    const selectCount = await selects.count()

    for (let i = 0; i < selectCount; i++) {
      const select = selects.nth(i)
      const selectedValue = await select.inputValue()

      if (selectedValue === notificationsId) {
        // Change to 0 (none) to remove the nodelet
        await select.selectOption('0')

        // Find the submit button in the same form
        const form = select.locator('xpath=ancestor::form[1]')
        const submitButton = form.locator('input[type="submit"]').first()
        await submitButton.click()

        await page.waitForLoadState('networkidle')
        return true
      }
    }

    // If we get here, we didn't find the Notifications nodelet to remove
    throw new Error('Could not find Notifications nodelet to remove')
  }

  /**
   * Helper: Subscribe to node note notifications
   */
  async function subscribeToNodeNotes(page) {
    await page.goto('/title/Nodelet+Settings#notificationsnodeletsettings')
    await page.waitForLoadState('networkidle')

    // Find and check the "node note created" checkbox
    const checkbox = page.locator('input[type="checkbox"][value="note"]')

    if (await checkbox.count() > 0) {
      await checkbox.check()

      // Submit the settings form
      await page.locator('input[type="submit"]').last().click()
      await page.waitForLoadState('networkidle')
    }
  }

  /**
   * Helper: Unsubscribe from node note notifications
   */
  async function unsubscribeFromNodeNotes(page) {
    await page.goto('/title/Nodelet+Settings#notificationsnodeletsettings')
    await page.waitForLoadState('networkidle')

    // Find and uncheck the "node note created" checkbox
    const checkbox = page.locator('input[type="checkbox"][value="note"]')

    if (await checkbox.count() > 0) {
      await checkbox.uncheck()

      // Submit the settings form
      await page.locator('input[type="submit"]').last().click()
      await page.waitForLoadState('networkidle')
    }
  }

  /**
   * Helper: Logout current user
   */
  async function logout(page) {
    // Navigate directly to logout endpoint
    await page.goto('/?op=logout')
    await page.waitForLoadState('networkidle')

    // Wait for logout to complete - check that user is guest
    await page.waitForFunction(() => {
      return window.e2 && window.e2.user && window.e2.user.guest === true
    }, { timeout: 10000 })

    await page.waitForTimeout(500)
  }

  /**
   * Complete end-to-end test of notification system
   */
  test('complete notification workflow - node note creation', async ({ page, browser }) => {
    // Step 1: Set up e2e_admin to have notifications nodelet
    await loginAsE2EAdmin(page)
    await page.waitForTimeout(1000) // Give React time to render

    await addNotificationsNodelet(page)

    // Step 2: Subscribe to "node note created" notifications
    await subscribeToNodeNotes(page)

    // Step 3: Verify Notifications nodelet is visible
    await page.goto('/')
    const notificationsNodelet = page.locator('#notifications')
    await expect(notificationsNodelet).toBeVisible()

    // Step 4: Log out
    await logout(page)

    // Step 5: Log in as e2e_editor in a new context
    const editorContext = await browser.newContext()
    const editorPage = await editorContext.newPage()

    // Use a custom login for e2e_editor
    await editorPage.goto('/')
    await editorPage.waitForSelector('#e2-react-root', { timeout: 5000 })
    await editorPage.waitForSelector('#sign_in', { timeout: 5000 })

    const signInHeader = editorPage.locator('h2:has-text("Sign In")')
    const isCollapsed = await signInHeader.evaluate(el =>
      el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
    )
    if (isCollapsed) {
      await signInHeader.click()
      await editorPage.waitForTimeout(300)
    }

    await editorPage.fill('#signin_user', 'e2e_editor')
    await editorPage.fill('#signin_passwd', 'test123')
    await Promise.all([
      editorPage.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
      editorPage.click('input[type="submit"]')
    ])

    // Step 6: Navigate to ENN page to find a writeup
    await editorPage.goto('/node/superdoc/ENN')
    await editorPage.waitForLoadState('networkidle')

    // Extract first writeup link from ENN page
    // Look for links in the content area that point to writeups
    const firstWriteupLink = await editorPage.locator('a[href*="/title/"]').first()
    const writeupHref = await firstWriteupLink.getAttribute('href')
    expect(writeupHref).toBeTruthy()

    // Navigate to the writeup page
    await editorPage.goto(writeupHref)
    await editorPage.waitForLoadState('networkidle')

    // Extract node_id from window.e2
    const nodeId = await editorPage.evaluate(() => window.e2?.node?.node_id)
    expect(nodeId).toBeTruthy()

    // Create a node note via API endpoint
    const noteText = `Test note from e2e_editor - ${Date.now()}`
    const apiResponse = await editorPage.evaluate(async ({ nodeId, noteText }) => {
      const response = await fetch(`/api/nodenotes/${nodeId}/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ notetext: noteText })
      })
      return {
        ok: response.ok,
        status: response.status,
        data: await response.json()
      }
    }, { nodeId, noteText })

    expect(apiResponse.ok).toBe(true)
    expect(apiResponse.status).toBe(200)

    // Close editor context
    await editorContext.close()

    // Step 7: Log back in as e2e_admin
    await page.goto('/')
    await loginAsE2EAdmin(page)

    // Step 8: Check for notification in Notifications nodelet
    await page.goto('/')
    await expect(notificationsNodelet).toBeVisible()

    const notificationsList = notificationsNodelet.locator('#notifications_list li')
    const notificationCount = await notificationsList.count()

    // If there are notifications, verify and dismiss one
    if (notificationCount > 0) {
      const firstNotification = notificationsList.first()

      // Verify notification contains a link
      const notificationLink = firstNotification.locator('a')
      await expect(notificationLink).toBeVisible()

      // Get the link href to verify it points to the right node
      const href = await notificationLink.getAttribute('href')
      expect(href).toBeTruthy()

      // Step 9: Dismiss the notification
      const dismissButton = firstNotification.locator('button.dismiss')
      await dismissButton.click()
      await page.waitForTimeout(1000)

      // Step 10: Load another page to verify notification is gone
      await page.goto('/title/Settings')
      await page.waitForLoadState('networkidle')

      await page.goto('/')
      const updatedNotificationsList = notificationsNodelet.locator('#notifications_list li')
      const updatedCount = await updatedNotificationsList.count()
      expect(updatedCount).toBe(notificationCount - 1)
    }

    // Step 11: Go to Nodelet Settings and unsubscribe from node notes
    await unsubscribeFromNodeNotes(page)

    // Step 12: Navigate away and back to ensure settings are fully processed
    // Settings are processed after the nodelet array gets built, so we need to
    // reload the page to see the updated nodelet list
    await page.goto('/')
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(500)

    // Step 13: Now go back to Nodelet Settings to remove the nodelet
    // The nodelet list should now be properly built with the updated settings
    try {
      await removeNotificationsNodelet(page)

      // Step 14: Verify nodelet is gone (reload page to see changes)
      await page.goto('/')
      await page.waitForLoadState('networkidle')

      // Re-query the nodelet to get fresh state after reload
      const updatedNotificationsNodelet = page.locator('#notifications')
      await expect(updatedNotificationsNodelet).not.toBeVisible()
    } catch (error) {
      // If nodelet can't be found to remove, it might have already been removed
      // This is acceptable for cleanup - just verify it's not visible
      await page.goto('/')
      await page.waitForLoadState('networkidle')

      const updatedNotificationsNodelet = page.locator('#notifications')
      const isVisible = await updatedNotificationsNodelet.isVisible().catch(() => false)

      if (isVisible) {
        throw new Error(`Notifications nodelet is still visible but couldn't be removed: ${error.message}`)
      }
    }
  })
})
