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

  // Click and wait for JavaScript redirect
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
    page.click('input[type="submit"]')
  ])

  // Wait for React to render epicenter (always present for logged-in users)
  await page.waitForSelector('#epicenter', { timeout: 5000 })
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

  // Click and wait for JavaScript redirect
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
    page.click('input[type="submit"]')
  ])

  // Wait for React to render epicenter (always present for logged-in users)
  await page.waitForSelector('#epicenter', { timeout: 5000 })
}

/**
 * Login as e2e_admin user (admin via gods group)
 * Uses the Sign In nodelet that appears on the homepage
 */
async function loginAsE2EAdmin(page) {
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

  await page.fill('#signin_user', 'e2e_admin')
  await page.fill('#signin_passwd', 'test123')

  // Click and wait for JavaScript redirect
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
    page.click('input[type="submit"]')
  ])

  // Wait for React to render epicenter (always present for logged-in users)
  await page.waitForSelector('#epicenter', { timeout: 5000 })
}

/**
 * Login as e2e_user (regular test user)
 * Uses the Sign In nodelet that appears on the homepage
 */
async function loginAsE2EUser(page) {
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

  await page.fill('#signin_user', 'e2e_user')
  await page.fill('#signin_passwd', 'test123')

  // Click and wait for JavaScript redirect
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }),
    page.click('input[type="submit"]')
  ])

  // Wait for React to render epicenter (always present for logged-in users)
  await page.waitForSelector('#epicenter', { timeout: 5000 })
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
  loginAsE2EAdmin,
  loginAsE2EUser,
  visitAsGuest
}
