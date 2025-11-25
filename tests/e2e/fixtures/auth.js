/**
 * Authentication helpers for E2E tests
 *
 * Provides reusable login functions to reduce test boilerplate
 */

/**
 * Login as root user (admin)
 * Uses the Sign In nodelet that appears on the homepage
 */
async function loginAsRoot(page) {
  await page.goto('/')

  // Expand Sign In nodelet if collapsed
  const signInHeader = page.locator('h2:has-text("Sign In")')
  const isCollapsed = await signInHeader.evaluate(el =>
    el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
  )
  if (isCollapsed) {
    await signInHeader.click()
    await page.waitForTimeout(300) // Wait for expand animation
  }

  await page.fill('#signin_user', 'root')
  await page.fill('#signin_passwd', 'blah')
  await page.click('input[type="submit"][value="Login"]')
  await page.waitForLoadState('networkidle')
}

/**
 * Login as generic test user
 * Uses the Sign In nodelet that appears on the homepage
 */
async function loginAsGenericDev(page) {
  await page.goto('/')

  // Expand Sign In nodelet if collapsed
  const signInHeader = page.locator('h2:has-text("Sign In")')
  const isCollapsed = await signInHeader.evaluate(el =>
    el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
  )
  if (isCollapsed) {
    await signInHeader.click()
    await page.waitForTimeout(300) // Wait for expand animation
  }

  await page.fill('#signin_user', 'genericdev')
  await page.fill('#signin_passwd', 'blah')
  await page.click('input[type="submit"][value="Login"]')
  await page.waitForLoadState('networkidle')
}

/**
 * Visit site as guest (not logged in)
 */
async function visitAsGuest(page) {
  await page.goto('/')
}

module.exports = {
  loginAsRoot,
  loginAsGenericDev,
  visitAsGuest
}
