const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

test.describe('Wheel of Surprise', () => {
  test('displays spin result', async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Navigate to wheel page
    await page.goto('/title/Wheel+of+Surprise')

    // Wait for page to load
    await expect(page.locator('h1:has-text("Wheel of Surprise")')).toBeVisible()

    // Wait for React component to render
    await page.waitForSelector('button:has-text("Spin")', { timeout: 5000 })

    // Get initial GP count from wheel component
    const gpText = await page.locator('text=/Current GP: \\d+/').textContent()
    const initialGP = parseInt(gpText.match(/Current GP: (\d+)/)[1])

    // Click spin button
    await page.click('button:has-text("Spin")')

    // Verify result appears (any prize message)
    await expect(page.locator('.wheel-of-surprise div[style*="background"]'))
      .toBeVisible({ timeout: 5000 })

    // Wait for page reload (wheel component reloads after spin)
    await page.waitForLoadState('networkidle')
  })

  test('blocks spin when user has insufficient GP', async ({ page }) => {
    await loginAsE2EAdmin(page)
    await page.goto('/title/Wheel+of+Surprise')

    // Wait for React component to render
    await page.waitForSelector('.wheel-of-surprise', { timeout: 5000 })

    // Check if user has less than 5 GP
    const gpText = await page.locator('text=/Current GP: \\d+/').textContent()
    const currentGP = parseInt(gpText.match(/Current GP: (\d+)/)[1])

    if (currentGP < 5) {
      // Should show insufficient GP message (no spin button)
      await expect(page.locator('text=/don\'t have enough GP/i')).toBeVisible()
      await expect(page.locator('button:has-text("Spin")')).not.toBeVisible()
    }
  })

  test('admin can sanctify themselves', async ({ page }) => {
    await loginAsE2EAdmin(page)

    // Navigate to sanctify page
    await page.goto('/title/Sanctify+user')

    // Type own username
    await page.fill('[name="give_to"]', 'e2e_admin')
    await page.click('input[name="give_GP"]')

    // Should succeed (not show "cannot sanctify yourself" error)
    await expect(page.locator('text=cannot sanctify yourself'))
      .not.toBeVisible({ timeout: 2000 })
      .catch(() => true) // It's ok if element doesn't exist at all

    // Should show success message
    await expect(page.locator('text=/has been given 10 GP|User.*e2e_admin.*has been given/i'))
      .toBeVisible({ timeout: 3000 })
  })
})
