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

  // Expand Sign In nodelet if collapsed
  const signInHeader = page.locator('h2:has-text("Sign In")')
  const isCollapsed = await signInHeader.evaluate(el =>
    el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
  )
  if (isCollapsed) {
    await signInHeader.click()
    await page.waitForTimeout(300)
  }

  await page.fill('#signin_user', 'e2e_admin')
  await page.fill('#signin_passwd', 'test123')

  // Click and wait for JavaScript redirect
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
    page.click('input[type="submit"]')
  ])

  // Wait for React to render - epicenter nodelet is always visible for logged-in users
  await page.waitForSelector('#epicenter', { timeout: 10000 })

  // Navigate to Settings
  await page.goto('http://localhost:9080/title/Settings')
  await page.waitForLoadState('networkidle')

  // Wait for React Settings page to render
  await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })

  // The checkbox structure in Settings.js is: <label><input type="checkbox"><strong>Ask for confirmation when voting</strong></label>
  // Find the label containing the text and get its checkbox
  const votesafetyLabel = page.locator('label:has(strong:text("Ask for confirmation when voting"))')
  await expect(votesafetyLabel).toBeVisible({ timeout: 5000 })
  const votesafetyCheckbox = votesafetyLabel.locator('input[type="checkbox"]')

  // Get original votesafety value for cleanup
  const originalChecked = await votesafetyCheckbox.isChecked()
  console.log('Original votesafety checked:', originalChecked)

  // Toggle votesafety checkbox - click the label for better accessibility
  await votesafetyLabel.click()

  // Wait for dirty state - the Settings component should enable Save button when dirty
  await expect(page.locator('button:has-text("Save Changes"):not([disabled])')).toBeVisible({ timeout: 3000 })

  // Click Save
  await page.click('button:has-text("Save Changes")')

  // Wait for button to become disabled again (indicating save completed)
  await expect(page.locator('button:has-text("Save Changes")[disabled]')).toBeVisible({ timeout: 5000 })

  // Reload the page
  await page.reload()
  await page.waitForLoadState('networkidle')

  // Wait for React to render again
  await page.waitForSelector('#e2-react-page-root', { timeout: 10000 })

  // Re-find the checkbox after reload
  const reloadedLabel = page.locator('label:has(strong:text("Ask for confirmation when voting"))')
  await expect(reloadedLabel).toBeVisible({ timeout: 5000 })
  const reloadedCheckbox = reloadedLabel.locator('input[type="checkbox"]')

  // Check if votesafety is still toggled
  const newChecked = await reloadedCheckbox.isChecked()
  console.log('After save votesafety checked:', newChecked)

  expect(newChecked).toBe(!originalChecked)

  // Restore original value
  if (newChecked !== originalChecked) {
    await reloadedLabel.click()
    await expect(page.locator('button:has-text("Save Changes"):not([disabled])')).toBeVisible({ timeout: 3000 })
    await page.click('button:has-text("Save Changes")')
    await expect(page.locator('button:has-text("Save Changes")[disabled]')).toBeVisible({ timeout: 5000 })
  }
})
