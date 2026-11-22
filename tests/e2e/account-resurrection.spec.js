const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAsE2EAdmin, openSignInForm } = require('./fixtures/auth')
const { activeAccount } = require('./fixtures/signup')
const { sentEmail } = require('./fixtures/email')

/**
 * Bringing back a deleted account (#4716).
 *
 * An admin finds the deleted account in The Node Crypt (its stored copy keeps the email address
 * but no password) and resurrects it in Dr. Nate's Secret Lab, which says the account has no
 * password. Its owner can't sign in with the old one; they reset it from the emailed link and
 * are signed in.
 *
 * Setup (harness): an active account with a known password, then deleted. Cleanup deletes it
 * without a tomb copy and removes any tomb row.
 * Watch: `./tools/e2e-demo.sh account-resurrection`.
 */
test('an admin resurrects a deleted account and its owner resets the password', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 120000)
  const uname = 'e2z' + Date.now().toString(36) // nick is varchar(20)
  const oldpass = 'oldpass123'
  const newpass = 'newpass456'
  const admin = await demo.actor(browser, 'e2e_admin (admin)', '#38495e')
  const member = await demo.actor(browser, `${uname} (account owner)`, '#2f6f8f')
  const { page } = admin
  const mine = member.page

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -e '${code}' ${uname}`

  const cleanup = async () => {
    await demo.shell(
      admin,
      perl('initEverything; my $u = $DB->getNode(shift, "user"); $DB->nukeNode($u, -1, 1) if $u; print "ok"') +
        ` && docker exec e2devdb mysql -u root -pblah everything -e "DELETE FROM tomb WHERE title='${uname}'" 2>/dev/null`,
      `removes the test account ${uname}`
    )
  }

  await demo.scenario('account-resurrection', [admin, member], async () => {
    await Promise.all([loginAsE2EAdmin(page), mine.goto('/')])

    await activeAccount(browser, member, uname, oldpass)
    await demo.shell(
      admin,
      perl('initEverything; my $u = $DB->getNode(shift, "user") or die "no user"; print $DB->nukeNode($u, $DB->getNode("root", "user")) ? "deleted" : "not deleted"'),
      `deletes the account ${uname}`,
      { result: (o) => o.trim() }
    )

    await page.goto('/title/The%20Node%20Crypt')
    const entry = page.locator('.node-crypt__list-table a', { hasText: uname })
    await expect(entry).toHaveCount(1, { timeout: 10000 })
    await demo.step(page, 'opens The Node Crypt and finds the deleted account')
    await demo.show(entry)

    await demo.click(entry)
    const coffin = page.locator('.node-crypt__coffin-table')
    await expect(coffin).toBeVisible({ timeout: 10000 })
    const cell = (name) => page.getByRole('cell', { name, exact: true })
    const row = (name) => coffin.locator('tr', { has: cell(name) })
    await expect(row('email')).toHaveCount(1)
    await expect(row('email')).toContainText(`${uname}@test.example.com`)
    for (const name of ['passwd', 'salt', 'validationkey']) await expect(row(name)).toHaveCount(0)
    await demo.step(page, 'opens its coffin: the email address is kept, no password')
    await demo.show(row('email'))

    await demo.click(page.locator('.node-crypt__heading a', { hasText: 'RESURRECT' }))
    const done = page.locator('.dr-nates-lab__result--success')
    await expect(done).toContainText('Resurrected as', { timeout: 10000 })
    const note = done.locator('.dr-nates-lab__password-note')
    await expect(note).toContainText('The account has no password')
    await demo.step(page, "follows RESURRECT: the Lab restores it and says it has no password")
    await demo.show(note)

    await mine.goto('/')
    const { form, userField, passField } = await openSignInForm(mine)
    await userField.fill(uname)
    await passField.fill(oldpass)
    await demo.step(mine, 'tries to sign in with their old password')
    await demo.click(form.locator('button[type="submit"]').first())
    const refused = form.locator('.login-error')
    await expect(refused).toContainText('Invalid username or password', { timeout: 10000 })
    expect(await mine.evaluate(() => window.e2 && window.e2.user && window.e2.user.guest)).toBe(true)
    await demo.show(refused)

    await mine.goto('/node/superdoc/Reset+password')
    const resetForm = mine.locator('.reset-password form')
    await resetForm.locator('#who').fill(uname)
    await resetForm.locator('#password').fill(newpass)
    await resetForm.locator('#passwordConfirm').fill(newpass)
    await demo.step(mine, 'asks for a password reset')
    const [requested] = await Promise.all([
      mine.waitForResponse((r) => r.url().includes('/api/password/reset-request') && r.request().method() === 'POST'),
      demo.click(resetForm.locator('button[type="submit"]')),
    ])
    expect((await requested.json()).success).toBeTruthy()
    const sent = mine.locator('.reset-password__success')
    await expect(sent).toContainText('Your password reset link is on its way')
    await demo.show(sent)

    const mail = await sentEmail(member, uname)
    expect(mail.to).toContain(`${uname}@test.example.com`)
    expect(mail.subject).toBe('Everything2 password reset')
    await mine.goto(mail.link)
    const confirm = mine.locator('form').filter({ has: mine.locator('button.confirm-password__button') })
    await confirm.locator('input[name="passwd"]').fill(newpass)
    await demo.step(mine, 'opens the link from the email and confirms the new password')
    const [confirmed] = await Promise.all([
      mine.waitForResponse((r) => r.url().includes('/api/users/confirm') && r.request().method() === 'POST'),
      demo.click(mine.locator('button.confirm-password__button')),
    ])
    expect(confirmed.status()).toBe(200)
    await mine.waitForFunction(
      (u) => window.e2 && window.e2.user && window.e2.user.guest === false && window.e2.user.title === u,
      uname,
      { timeout: 15000 }
    )
    const epicenter = mine.locator('#epicenter')
    await expect(epicenter).toContainText(uname, { timeout: 10000 })
    await demo.step(mine, 'signed in to their account again')
    await demo.show(epicenter)
  }, { cleanup })
})
