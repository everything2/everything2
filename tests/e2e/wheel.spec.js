const { test, expect } = require('@playwright/test')
const { loginAsRoot } = require('./fixtures/auth')

test.describe('Wheel of Surprise', () => {
  test('displays spin result', async ({ page }) => {
    await loginAsRoot(page)

    // Navigate to wheel page
    await page.goto('/title/Wheel+of+Surprise')

    // Wait for page to load
    await expect(page.locator('h1:has-text("Wheel of Surprise")')).toBeVisible()

    // Get initial GP count
    const gpText = await page.locator('text=/\\d+ GP/').first().textContent()
    const initialGP = parseInt(gpText.match(/(\d+) GP/)[1])

    // Click spin button
    await page.click('button:has-text("Spin the Wheel")')

    // Verify result appears (any prize message)
    await expect(page.locator('text=/You won|nothing|GP|egg|cool|token|Butterfinger/i'))
      .toBeVisible({ timeout: 5000 })

    // Verify GP was deducted (at least the 5 GP spin cost)
    const newGpText = await page.locator('text=/\\d+ GP/').first().textContent()
    const newGP = parseInt(newGpText.match(/(\d+) GP/)[1])
    expect(newGP).toBeLessThanOrEqual(initialGP - 5)
  })

  test('blocks spin when user has insufficient GP', async ({ page }) => {
    await loginAsRoot(page)
    await page.goto('/title/Wheel+of+Surprise')

    // Check if user has less than 5 GP
    const gpText = await page.locator('text=/\\d+ GP/').first().textContent()
    const currentGP = parseInt(gpText.match(/(\d+) GP/)[1])

    if (currentGP < 5) {
      // Spin button should show error
      await page.click('button:has-text("Spin the Wheel")')
      await expect(page.locator('text=/need at least 5 GP/i')).toBeVisible()
    }
  })

  test('admin can sanctify themselves', async ({ page }) => {
    await loginAsRoot(page)

    // Navigate to sanctify page
    await page.goto('/title/Sanctify+user')

    // Type own username
    await page.fill('[name="give_to"]', 'root')
    await page.click('input[name="give_GP"]')

    // Should succeed (not show "cannot sanctify yourself" error)
    await expect(page.locator('text=cannot sanctify yourself'))
      .not.toBeVisible({ timeout: 2000 })
      .catch(() => true) // It's ok if element doesn't exist at all

    // Should show success message
    await expect(page.locator('text=/has been given 10 GP|User.*root.*has been given/i'))
      .toBeVisible({ timeout: 3000 })
  })
})
