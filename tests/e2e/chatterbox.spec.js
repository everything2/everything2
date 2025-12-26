const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Chatterbox E2E Tests
 *
 * Tests the React Chatterbox component functionality:
 * - Message sending and display
 * - Special commands (/me, /roll, /clearchatter)
 * - UI behavior (focus retention, layout stability)
 * - Character counter
 *
 * CLEANUP STRATEGY:
 * - Each test uses /clearchatter before starting to ensure clean state
 * - Tests use unique timestamps in messages to avoid conflicts
 * - No persistent state left behind - chatter cleared at test start
 *
 * TEST USER:
 * - Uses e2e_admin (has admin privileges, password: test123)
 * - Admin required for /clearchatter command
 */

test.describe('Chatterbox', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Wait for chatterbox to load
    await page.waitForSelector('#chatterbox', { timeout: 10000 })
    await page.waitForSelector('#message', { timeout: 5000 })

    // Clear chatter to ensure clean state for each test
    await page.fill('#message', '/clearchatter')
    await page.click('#message_send')
    await page.waitForTimeout(500)
  })

  /**
   * Test: Message sending doesn't cause unexpected layout shift
   *
   * Purpose: Verify that sending a message when the chatterbox already has
   * content doesn't cause an unexpected height change. A small tolerance is
   * allowed since scrollbars may appear/disappear.
   *
   * Steps:
   * 1. Send an initial message to populate the chatter
   * 2. Measure chatterbox height with content
   * 3. Send a second message
   * 4. Verify second message appears
   * 5. Verify chatterbox height stays within tolerance
   *
   * Cleanup: Message cleared by next test's beforeEach
   */
  test('sends message without layout shift', async ({ page }) => {
    // Wait for chatterbox to be visible and rendered
    const chatterbox = page.locator('#chatterbox')
    await chatterbox.waitFor({ state: 'visible', timeout: 10000 })

    // Scroll chatterbox into view
    await chatterbox.scrollIntoViewIfNeeded()

    // First, send an initial message to ensure chatter has content
    // (empty chatter expanding to show content is expected behavior, not a layout shift)
    const initMessage = 'init message ' + Date.now()
    await page.fill('#message', initMessage)
    await page.click('#message_send')
    await page.waitForTimeout(1000)
    await expect(page.locator(`#chatterbox_chatter:has-text("${initMessage}")`)).toBeVisible()

    // Wait a bit for any animations/layout to settle
    await page.waitForTimeout(500)

    // Now measure the height with content present
    const initialBox = await chatterbox.boundingBox()

    // If boundingBox is null, element might not be properly rendered
    if (!initialBox) {
      throw new Error('Chatterbox bounding box is null - element may not be visible or have zero dimensions')
    }

    // Type and send another message with timestamp to ensure uniqueness
    const testMessage = 'test message ' + Date.now()
    await page.fill('#message', testMessage)
    await page.click('#message_send')

    // Wait for message to appear in chatter
    await page.waitForTimeout(1000)
    await expect(page.locator(`#chatterbox_chatter:has-text("${testMessage}")`)).toBeVisible()

    // Verify no significant layout shift occurred
    // Allow a small tolerance (20px) for scrollbar appearance/disappearance
    const afterBox = await chatterbox.boundingBox()
    expect(Math.abs(afterBox.height - initialBox.height)).toBeLessThanOrEqual(20)
  })

  /**
   * Test: Special commands render correctly
   *
   * Purpose: Verify that chatter special commands (/me, /roll) render
   * with correct formatting (italics, dice results).
   *
   * Steps:
   * 1. Send /me command
   * 2. Verify italic formatting in chatter
   * 3. Send /roll command
   * 4. Verify roll result appears
   *
   * Cleanup: Messages cleared by next test's beforeEach
   */
  test('special commands render correctly', async ({ page }) => {
    // Test /me command
    await page.fill('#message', '/me waves hello')
    await page.click('#message_send')

    // Verify italic formatting appears in chatter
    await page.waitForTimeout(1000) // Wait for message to appear in chatter
    await expect(page.locator('#chatterbox_chatter em:has-text("e2e_admin waves hello")')).toBeVisible()

    // Test /roll command
    await page.fill('#message', '/roll 1d6')
    await page.click('#message_send')

    // Verify roll appears (with arrow symbol)
    await page.waitForTimeout(1000)
    await expect(page.locator('#chatterbox_chatter:has-text("e2e_admin rolls 1d6")')).toBeVisible()
  })

  /**
   * Test: Input retains focus after sending
   *
   * Purpose: Verify that the message input stays focused after sending
   * a message, allowing users to type follow-up messages immediately.
   *
   * Steps:
   * 1. Fill input and send message
   * 2. Wait for message to appear
   * 3. Verify input still has focus
   *
   * Cleanup: Message cleared by next test's beforeEach
   */
  test('input retains focus after sending', async ({ page }) => {
    const input = page.locator('#message')

    // Ensure chatterbox and input are visible before testing
    await expect(input).toBeVisible({ timeout: 10000 })

    // Send a message
    const testMessage = 'focus test ' + Date.now()
    await input.fill(testMessage)
    await page.click('#message_send')

    // Wait for message to appear in chatter (with longer timeout for network lag)
    await expect(page.locator(`#chatterbox_chatter:has-text("${testMessage}")`)).toBeVisible({ timeout: 10000 })

    // Input should still be focused
    await page.waitForTimeout(100)
    await expect(input).toBeFocused()
  })

  /**
   * Test: Character counter works
   *
   * Purpose: Verify that the character counter (if implemented) shows
   * message length relative to the 512 character limit.
   *
   * Steps:
   * 1. Type long message (500 chars)
   * 2. Verify counter shows near limit
   *
   * Note: This is a placeholder test - counter implementation may vary.
   * Update locator when character counter UI is finalized.
   *
   * Cleanup: Input cleared automatically (no message sent)
   */
  test('character counter works', async ({ page }) => {
    const input = page.locator('#message')

    // Type message
    await input.fill('a'.repeat(500))

    // Counter should show near limit
    // (Note: Implementation may vary, this is a placeholder)
    // await expect(page.locator('text=/500/512/')).toBeVisible()
  })
})
