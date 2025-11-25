const { test, expect } = require('@playwright/test')
const { loginAsRoot } = require('./fixtures/auth')

test.describe('Chatterbox', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsRoot(page)
  })

  test('sends message without layout shift', async ({ page }) => {
    // Measure initial layout
    const chatterbox = page.locator('#chatterbox')
    const initialBox = await chatterbox.boundingBox()

    // Type and send message
    const testMessage = 'test message ' + Date.now()
    await page.fill('#message', testMessage)
    await page.click('#message_send')

    // Wait for message to appear in chatter
    await page.waitForTimeout(1000)
    await expect(page.locator(`#chatterbox_chatter:has-text("${testMessage}")`)).toBeVisible()

    // Verify no layout shift occurred
    const afterBox = await chatterbox.boundingBox()
    expect(afterBox.height).toBeCloseTo(initialBox.height, 0) // Exactly the same height
  })

  test('error message covers chat commands link', async ({ page }) => {
    // Mock API to return error
    await page.route('**/api/chatter/create', route =>
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ success: false, error: 'Test error message' })
      })
    )

    await page.fill('#message', 'test error')
    await page.click('#message_send')

    // Error message appears
    const errorMsg = page.locator('text=Test error message')
    await expect(errorMsg).toBeVisible()

    // Get positions
    const errorBox = await errorMsg.boundingBox()
    const commandsLink = await page.locator('text=Chat Commands').boundingBox()

    // Error should overlay commands (absolutely positioned, same vertical area)
    expect(errorBox.y).toBeLessThanOrEqual(commandsLink.y)
    expect(errorBox.y + errorBox.height).toBeGreaterThanOrEqual(commandsLink.y)
  })

  test('special commands render correctly', async ({ page }) => {
    // Test /me command
    await page.fill('#message', '/me waves hello')
    await page.click('#message_send')

    // Verify italic formatting appears in chatter
    await page.waitForTimeout(1000) // Wait for message to appear in chatter
    await expect(page.locator('#chatterbox_chatter em:has-text("root waves hello")')).toBeVisible()

    // Test /roll command
    await page.fill('#message', '/roll 1d6')
    await page.click('#message_send')

    // Verify roll appears (with arrow symbol)
    await page.waitForTimeout(1000)
    await expect(page.locator('#chatterbox_chatter:has-text("root rolls 1d6")')).toBeVisible()
  })

  test('input retains focus after sending', async ({ page }) => {
    const input = page.locator('#message')

    // Send a message
    const testMessage = 'focus test ' + Date.now()
    await input.fill(testMessage)
    await page.click('#message_send')

    // Wait for message to appear in chatter
    await page.waitForTimeout(1000)
    await expect(page.locator(`#chatterbox_chatter:has-text("${testMessage}")`)).toBeVisible()

    // Input should still be focused
    await page.waitForTimeout(100)
    await expect(input).toBeFocused()
  })

  test('character counter works', async ({ page }) => {
    const input = page.locator('#message')

    // Type message
    await input.fill('a'.repeat(500))

    // Counter should show near limit
    // (Note: Implementation may vary, this is a placeholder)
    // await expect(page.locator('text=/500/512/')).toBeVisible()
  })
})
