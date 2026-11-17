/**
 * E2E: signing up, the plain path. One new person, start to finish:
 *   1. fills in the Sign up form (POST /api/signup);
 *   2. gets the welcome email and follows its activation link (dev keeps outgoing mail in a
 *      spool; fixtures/email.js reads it with tools/test-password-reset.pl --sent, shown on
 *      recordings as a TEST HARNESS card);
 *   3. sets their password on Confirm password, which activates the account and signs them in;
 *   4. later, in a fresh session, signs in with that username and password.
 *
 * Edge cases (two signups in a row, a lost activation email, expired links) live in
 * signup-confirm.spec.js. Watch this one: `./tools/e2e-demo.sh signup`
 * (E2E_DEMO_DEVICE=mobile for phones).
 */
const { test, expect } = require('@playwright/test')
const { loginAs } = require('./fixtures/auth')
const demo = require('./fixtures/demo')
const { sentEmail } = require('./fixtures/email')
const { signUpThroughForm, activateWith } = require('./fixtures/signup')

test('a new member signs up, activates with the emailed link, and signs in', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const uname = `e2n${Date.now().toString(36)}` // usernames max out at 20 characters
  const pass = 'newmember123'
  const email = `${uname}@test.example.com`
  const member = await demo.actor(browser, `${uname} (new member)`, '#38495e')
  const { page } = member

  await demo.scenario('signup', [member], async () => {
    await signUpThroughForm(member, uname, pass, email)

    const mail = await sentEmail(member, uname)
    expect(mail.subject).toBe('Welcome to Everything2')
    expect(mail.to).toContain(email)
    expect(mail.link).toContain('action=activate')
    expect(mail.link).toContain(`user=${uname}`)
    await activateWith(member, mail.link, pass, uname)

    // Later: a fresh session, the normal sign-in form.
    await demo.step(page, 'comes back later: a fresh session')
    await page.context().clearCookies()
    await demo.step(page, 'signs in with their username and password')
    await loginAs(page, uname, pass)
    await page.waitForFunction(
      (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
      uname,
      { timeout: 15000 }
    )
    const shown = member.device === 'mobile' ? page.locator('.e2-header-mobile-auth') : page.locator('#epicenter')
    if (member.device !== 'mobile') await expect(shown).toContainText(uname)
    await demo.step(page, `signed in as ${uname}`)
    await demo.show(shown, 2500)
  })
})
