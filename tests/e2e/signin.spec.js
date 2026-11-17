/**
 * E2E: signing in. A wrong password shows the usual error and is recorded in the security
 * log (Security Monitor: "Failed sign-ins"); the right password then signs in.
 *
 * The security log is checked with a read-only query against the dev database (shown on
 * recordings as TEST HARNESS cards). normaluser27 is used only by this spec, so its rows
 * are this spec's.
 *
 * Watch it: `./tools/e2e-demo.sh signin` (E2E_DEMO_DEVICE=mobile for phones).
 */
const { test, expect } = require('@playwright/test')
const { openSignInForm } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

const USER = 'normaluser27'
const PASS = 'blah'

// Failed sign-in rows (event 39) for USER: "count|latest details".
const seclogQuery =
  `docker exec e2devdb mysql -u root -pblah everything -N -e ` +
  `"SELECT COUNT(*), COALESCE(SUBSTRING_INDEX(GROUP_CONCAT(s.seclog_details ORDER BY s.seclog_id DESC), ',', 1), '-') ` +
  `FROM seclog s JOIN node n ON n.node_id = s.seclog_subject WHERE s.seclog_event = 39 AND n.title = '${USER}'" 2>/dev/null`
const parse = (out) => {
  const [count, latest] = out.trim().split(/\t/)
  return { count: Number(count), latest }
}

test('a wrong password is refused and logged; the right one signs in', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const member = await demo.actor(browser, `${USER} (signing in)`, '#38495e')
  const { page } = member

  await demo.scenario('signin', [member], async () => {
    await page.goto('/')
    const before = parse(await demo.shell(member, seclogQuery, `counts ${USER}'s failed sign-ins in the security log`,
      { result: (o) => `${parse(o).count} so far` }))

    // A typo in the password.
    await demo.step(page, 'signs in with a mistyped password')
    let { form, userField, passField } = await openSignInForm(page)
    await userField.fill(USER)
    await passField.fill('blahh')
    await demo.click(form.locator('button[type="submit"]').first())
    const error = form.locator('.login-error')
    await expect(error).toHaveText('Invalid username or password')
    await demo.step(page, 'told the username or password is wrong')
    await demo.show(error)
    await expect.poll(() => page.evaluate(() => window.e2.user.guest)).toBe(true)

    const after = parse(await demo.shell(member, seclogQuery, `checks the security log again`,
      { result: (o) => { const r = parse(o); return `${r.count} failed sign-ins; latest from ${r.latest}` } }))
    expect(after.count).toBe(before.count + 1)

    // The right password.
    await demo.step(page, 'tries again with the right password')
    ;({ form, userField, passField } = await openSignInForm(page))
    await userField.fill(USER)
    await passField.fill(PASS)
    await demo.click(form.locator('button[type="submit"]').first())
    await page.waitForFunction(
      (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
      USER,
      { timeout: 15000 }
    )
    const shown = member.device === 'mobile' ? page.locator('.e2-header-mobile-auth') : page.locator('#epicenter')
    if (member.device !== 'mobile') await expect(shown).toContainText(USER)
    await demo.step(page, `signed in as ${USER}`)
    await demo.show(shown, 2500)
  })
})
