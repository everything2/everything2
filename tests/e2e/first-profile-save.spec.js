const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { sentEmail } = require('./fixtures/email')
const { signUpThroughForm, activateWith } = require('./fixtures/signup')

/**
 * A brand-new member's first profile save works, and saving keeps their "last seen" time (#4709).
 *
 * Every signed-in request records the time in user.lasttime. A save of the user used to write
 * back whatever lasttime the saving copy held: an older time, or for a member never seen before,
 * an empty one (the database rejects that in development, so the save failed; production stored a
 * zero date). Now a save never writes lasttime.
 *
 * The member signs up through the form, activates from the emailed link, fills in the profile on
 * their Settings page and saves. Their homenode shows the profile and a "last seen" of today, and
 * the database (read on a TEST HARNESS card) has lasttime within the last minute.
 * Watch: `./tools/e2e-demo.sh first-profile-save` (E2E_DEMO_DEVICE=mobile too).
 */
test('a new member saves their profile for the first time and stays "last seen" now', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 240000 : 90000)
  const uname = `e2p${Date.now().toString(36)}` // nick is varchar(20)
  const pass = 'firstsave123'
  const member = await demo.actor(browser, `${uname} (new member)`, '#38495e')
  const { page } = member
  const mission = `Writing my first node, ${uname}.`

  const lastSeenAge = () =>
    demo.shell(
      member,
      `docker exec e2devdb mysql -u root -pblah everything -N -e "SELECT IFNULL(TIMESTAMPDIFF(SECOND, lasttime, NOW()), 'NULL') FROM user JOIN node ON node_id=user_id WHERE title='${uname}'" 2>/dev/null`,
      `reads ${uname}'s stored "last seen" time from the database`,
      { result: (o) => `last seen ${o.trim()} seconds ago` }
    ).then((o) => o.trim())

  await demo.scenario('first-profile-save', [member], async () => {
    await signUpThroughForm(member, uname, pass, `${uname}@test.example.com`)
    const mail = await sentEmail(member, uname)
    expect(mail.link).toContain('action=activate')
    await activateWith(member, mail.link, pass, uname)

    // First visit to their own Settings page.
    await page.goto(`/user/${encodeURIComponent(uname)}?displaytype=edit`)
    const form = page.locator('#profile-form')
    await expect(form).toBeVisible({ timeout: 10000 })
    await demo.step(page, 'opens their Settings page for the first time')

    await form.locator('input[name="realname"]').fill('First Saver')
    await form.locator('input[name="mission"]').fill(mission)
    await demo.step(page, 'fills in their real name and mission')
    await demo.show(form.locator('input[name="mission"]'))

    const [saved] = await Promise.all([
      page.waitForResponse((r) => r.url().includes('/api/user/edit') && r.request().method() === 'POST'),
      demo.click(page.locator('.user-edit-save-btn')),
    ])
    const body = await saved.json()
    expect(body.success, `save failed: ${body.error || ''}`).toBeTruthy()
    const ok = page.locator('.user-edit-status--success')
    await expect(ok).toContainText('Profile updated')
    await demo.step(page, 'saves: "Profile updated successfully!"')
    await demo.show(ok)

    // Their homenode shows the profile and that they were last seen today.
    await page.goto(`/user/${encodeURIComponent(uname)}`)
    const missionRow = page.locator('dt', { hasText: 'mission drive within everything' }).locator('xpath=following-sibling::dd[1]')
    await expect(missionRow).toContainText(mission, { timeout: 10000 })
    const lastSeen = page.locator('dt', { hasText: 'last seen' }).locator('xpath=following-sibling::dd[1]')
    await expect(lastSeen).toBeVisible()
    const today = new Date().toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'UTC' })
    await expect(lastSeen).toContainText(today)
    await demo.step(page, 'their homenode shows the profile and "last seen" today')
    await demo.show(lastSeen)
    await demo.show(missionRow)

    const age = await lastSeenAge()
    expect(age, 'lasttime is set, not NULL').not.toBe('NULL')
    expect(Number(age), 'lasttime is the time of their last request').toBeLessThan(60)
    expect(Number(age)).toBeGreaterThanOrEqual(0)
    await demo.step(page, 'the stored "last seen" time is current')
  })
})
