/**
 * Settings Persistence E2E Tests
 *
 * CLEANUP STRATEGY: Tests read and restore original votesafety value
 * TEST USERS: e2e_admin (gods, pw:test123)
 */

import { test, expect } from '@playwright/test'

test('votesafety preference persists across page loads', async ({ page }) => {
  // Login as e2e_admin
  await page.goto('http://localhost:9080/')
  await page.fill('input[name="user"]', 'e2e_admin')
  await page.fill('input[name="passwd"]', 'test123')
  await page.click('input[name="login"]', { force: true })

  // Wait for login to complete
  await page.waitForLoadState('networkidle')

  // Navigate to Settings
  await page.goto('http://localhost:9080/title/Settings')
  await page.waitForLoadState('networkidle')

  // Find the votesafety checkbox by its label text
  const votesafetyCheckbox = page.locator('label:has-text("Ask for confirmation when voting") input[type="checkbox"]')

  // Get original votesafety value for cleanup
  const originalChecked = await votesafetyCheckbox.isChecked()
  console.log('Original votesafety checked:', originalChecked)

  // Toggle votesafety checkbox
  await votesafetyCheckbox.click()

  // Wait for dirty state
  await expect(page.locator('text=You have unsaved changes')).toBeVisible()

  // Click Save
  await page.click('button:has-text("Save Changes")')

  // Wait for success message
  await expect(page.locator('text=Settings saved successfully')).toBeVisible({ timeout: 5000 })

  // Reload the page
  await page.reload()
  await page.waitForLoadState('networkidle')

  // Check if votesafety is still toggled
  const newChecked = await votesafetyCheckbox.isChecked()
  console.log('After save votesafety checked:', newChecked)

  expect(newChecked).toBe(!originalChecked)

  // Restore original value
  if (newChecked !== originalChecked) {
    await votesafetyCheckbox.click()
    await page.click('button:has-text("Save Changes")')
    await expect(page.locator('text=Settings saved successfully')).toBeVisible({ timeout: 5000 })
  }
})
