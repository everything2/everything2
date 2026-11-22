/**
 * Signing up through the real UI, shared by signup.spec.js and signup-confirm.spec.js.
 * Each step is captioned and highlighted on demo recordings (fixtures/demo.js).
 */
const { expect } = require('@playwright/test')
const demo = require('./demo')

// Fill in and submit the real Sign Up form as `who`; waits for the success message.
async function signUpThroughForm(who, uname, pass, email) {
  const { page } = who
  await page.goto('/node/superdoc/Sign+up')
  await demo.step(page, 'opens Sign up')
  const form = page.locator('form').filter({ has: page.locator('button.signup__submit') })
  await form.locator('input[type="text"]').first().fill(uname)
  await form.locator('input[type="password"]').nth(0).fill(pass)
  await form.locator('input[type="password"]').nth(1).fill(pass)
  await form.locator('input[type="email"]').nth(0).fill(email)
  await form.locator('input[type="email"]').nth(1).fill(email)
  const submit = form.locator('button.signup__submit')
  await expect(submit).toBeEnabled({ timeout: 10000 }); // after the username availability check
  await demo.step(page, `fills in the form as ${uname}`)
  await demo.show(form)
  const [resp] = await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/signup') && r.request().method() === 'POST'),
    demo.click(submit),
  ])
  expect((await resp.json()).success).toBeTruthy()
  const welcome = page.locator('.signup__success-title')
  await expect(welcome).toContainText(uname)
  await demo.step(page, 'account created: told to check their email')
  await demo.show(welcome)
}

// Follow an activation link and set the password on the Confirm password form.
async function activateWith(who, link, pass, uname) {
  const { page } = who
  await page.goto(link)
  await demo.step(page, 'opened the activation link from their email')
  const form = page.locator('form').filter({ has: page.locator('button.confirm-password__button') })
  await demo.show(form)
  await form.locator('input[name="passwd"]').fill(pass)
  const [resp] = await Promise.all([
    page.waitForResponse((r) => r.url().includes('/api/users/confirm') && r.request().method() === 'POST'),
    demo.click(page.locator('button.confirm-password__button')),
  ])
  expect(resp.status()).toBe(200)
  await page.waitForFunction(
    (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
    uname,
    { timeout: 15000 }
  )
  const shown = who.device === 'mobile' ? page.locator('.e2-header-mobile-auth') : page.locator('#epicenter')
  if (who.device !== 'mobile') await expect(shown).toContainText(uname, { timeout: 10000 })
  await demo.step(page, `account activated: signed in as ${uname}`)
  await demo.show(shown, 2500)
}

// An account that has been activated and used, so a reset request sends a reset link.
// who: the recorded actor the harness cards appear on.
async function activeAccount(browser, who, uname, pass) {
  const out = await demo.shell(
    who,
    `docker exec e2devapp perl /var/everything/tools/test-signup.pl ${uname} ${pass}`,
    `creates the test account ${uname}`,
    { result: () => 'account created; activation link printed by the tool' }
  )
  const links = out.match(/\/node\/superdoc\/Confirm\+password\?[^\s"<]+/g) || []
  const activation = links.find((l) => !l.includes('&amp;')) || links[links.length - 1]
  expect(activation, 'activation link from test-signup.pl').toBeTruthy()
  const ctx = await browser.newContext()
  const page = await ctx.newPage()
  await page.goto(activation)
  await page.locator('form').filter({ has: page.locator('button.confirm-password__button') }).locator('input[name="passwd"]').fill(pass)
  await page.locator('button.confirm-password__button').click()
  await page.waitForFunction(
    (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
    uname,
    { timeout: 15000 }
  )
  await page.goto('/') // a signed-in visit, so the account counts as used
  await ctx.close()
  await demo.note(who, `activates ${uname} and signs in once`,
    'In a separate browser session that is not recorded: followed the activation link, set the password, ' +
    'and visited the site, so the account counts as active (a reset request for an account never used ' +
    'sends an activation link instead).')
}

module.exports = { signUpThroughForm, activateWith, activeAccount }
