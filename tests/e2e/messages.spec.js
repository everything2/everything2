const { test, expect } = require('@playwright/test')
const { loginAsRoot } = require('./fixtures/auth')

test.describe('Mini Messages', () => {
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
    await loginAsRoot(page)

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

  test('mini messages only show when Messages nodelet not in sidebar', async ({ page }) => {
    await loginAsRoot(page)

    const miniMessages = page.locator('#chatterbox_messages')
    const messagesNodelet = page.locator('#nodelet_2044453') // Messages nodelet ID

    // Either mini messages show OR Messages nodelet shows, never both
    const miniVisible = await miniMessages.isVisible({ timeout: 1000 }).catch(() => false)
    const nodeletVisible = await messagesNodelet.isVisible({ timeout: 1000 }).catch(() => false)

    // Exactly one should be visible (XOR)
    expect(miniVisible !== nodeletVisible).toBe(true)
  })
})
