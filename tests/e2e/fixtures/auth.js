/**
 * Authentication helpers for E2E tests
 *
 * Provides reusable login functions to reduce test boilerplate. They work at desktop
 * and mobile sizes: desktop signs in through the Sign In nodelet, mobile (no sidebar)
 * through the header's Sign In button and its modal. Both use the same form fields.
 */

/**
 * Open the sign-in form on the current page: the Sign In nodelet on desktop (expanded if
 * collapsed), the header Sign In button's modal on mobile. Returns { form, userField, passField }.
 */
async function openSignInForm(page) {
  await page.waitForSelector('#e2-react-page-root', { timeout: 5000 })
  const nodelet = page.locator('#sign_in')
  const headerButton = page.locator('.e2-header-signin-btn')
  await nodelet.or(headerButton).first().waitFor({ state: 'visible', timeout: 5000 })

  if (await nodelet.isVisible()) {
    // Desktop: expand the Sign In nodelet if collapsed.
    const signInHeader = page.locator('h2:has-text("Sign In")')
    const isCollapsed = await signInHeader.evaluate(el =>
      el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'
    )
    if (isCollapsed) {
      await signInHeader.click()
      await page.waitForTimeout(300) // expand animation
    }
    return { form: nodelet, userField: nodelet.locator('#signin_user').first(), passField: nodelet.locator('#signin_passwd').first() }
  }
  // Mobile: the header button opens the sign-in modal (Log In tab is the default). After a
  // failed attempt the modal is still open, so reuse it.
  const form = page.locator('.auth-modal form').filter({ has: page.locator('input[type="password"]') }).first()
  if (!(await form.isVisible())) await headerButton.click({ timeout: 10000 })
  await form.waitFor({ state: 'visible', timeout: 5000 })
  return { form, userField: form.locator('input[type="text"]').first(), passField: form.locator('input[type="password"]').first() }
}

/**
 * Login as any user. Waits for window.e2.user to show a logged-in session.
 *
 * Login can be a client-side fetch with no full navigation, so this does NOT
 * waitForNavigation (it would hang on the background pollers); the window.e2.user
 * check is the real "we're logged in" signal.
 */
async function loginAs(page, username, password) {
  await page.goto('/')
  const { form, userField, passField } = await openSignInForm(page)
  await userField.fill(username)
  await passField.fill(password)
  await form.locator('button[type="submit"]').first().click()

  await page.waitForFunction(() => window.e2 && window.e2.user && window.e2.user.guest === false, { timeout: 15000 })
}

/** Login as root user (admin) */
async function loginAsRoot(page) {
  return loginAs(page, 'root', 'blah')
}

/** Login as generic test user */
async function loginAsGenericDev(page) {
  return loginAs(page, 'genericdev', 'blah')
}

/** Login as e2e_admin user (admin via gods group) */
async function loginAsE2EAdmin(page) {
  return loginAs(page, 'e2e_admin', 'test123')
}

/** Login as e2e_editor (Content Editors member, not an admin) */
async function loginAsE2EEditor(page) {
  return loginAs(page, 'e2e_editor', 'test123')
}

/** Login as e2e_user (regular test user) */
async function loginAsE2EUser(page) {
  return loginAs(page, 'e2e_user', 'test123')
}

/**
 * Visit site as guest (not logged in)
 */
async function visitAsGuest(page) {
  await page.goto('/')
}

module.exports = {
  loginAs,
  openSignInForm,
  loginAsRoot,
  loginAsGenericDev,
  loginAsE2EAdmin,
  loginAsE2EEditor,
  loginAsE2EUser,
  visitAsGuest
}
