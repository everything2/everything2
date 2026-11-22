const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * The Node Crypt and Dr. Nate's Secret Lab: a deleted node's stored copy can be viewed and the
 * node brought back.
 *
 * An admin deletes a draft (setup, through the drafts API: the same nuke path a member's delete
 * takes), finds it in The Node Crypt, opens its coffin to see the stored fields, and follows
 * RESURRECT to the Lab, which restores it. The restored draft opens with its title and text.
 * Cleanup deletes it again and removes that tomb row.
 * Watch: `./tools/e2e-demo.sh node-crypt`.
 */
test('an admin views a deleted node in The Node Crypt and resurrects it', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const admin = await demo.actor(browser, 'e2e_admin (admin)', '#38495e')
  const { page } = admin
  const stamp = Date.now()
  const title = `Crypt keeper draft ${stamp}`
  const text = `Brought back from the crypt ${stamp}.`
  let draftId = null

  const api = (path, method, body) =>
    page.evaluate(
      async ({ path, method, body }) => {
        const res = await fetch(path, {
          method,
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: body ? JSON.stringify(body) : undefined,
        })
        return res.json().catch(() => ({}))
      },
      { path, method, body }
    )

  const cleanup = async () => {
    if (!draftId) return
    await api(`/api/drafts/${draftId}`, 'DELETE').catch(() => {})
    await demo.shell(
      admin,
      `docker exec e2devdb mysql -u root -pblah everything -e "DELETE FROM tomb WHERE node_id=${Number(draftId)}" 2>/dev/null`,
      'removes the test draft from the tomb'
    )
  }

  await demo.scenario('node-crypt', [admin], async () => {
    await loginAsE2EAdmin(page)

    const created = await api('/api/drafts', 'POST', { title, doctext: `<p>${text}</p>` })
    expect(created.success).toBeTruthy()
    draftId = created.draft.node_id
    const deleted = await api(`/api/drafts/${draftId}`, 'DELETE')
    expect(deleted.success, JSON.stringify(deleted)).toBeTruthy()
    await demo.note(admin, 'Setup', `created and deleted the draft "${title}" (node ${draftId})`)

    await page.goto('/title/The%20Node%20Crypt')
    const entry = page.locator('.node-crypt__list-table a', { hasText: title })
    await expect(entry).toHaveCount(1, { timeout: 10000 })
    await demo.step(page, 'opens The Node Crypt and finds the deleted draft')
    await demo.show(entry)

    await demo.click(entry)
    const coffin = page.locator('.node-crypt__coffin-table')
    await expect(coffin).toBeVisible({ timeout: 10000 })
    const doctextRow = coffin.locator('tr', { hasText: 'doctext' })
    await expect(doctextRow).toContainText(text)
    await demo.step(page, 'opens its coffin: the stored copy, field by field')
    await demo.show(doctextRow)

    await demo.click(page.locator('.node-crypt__heading a', { hasText: 'RESURRECT' }))
    const done = page.locator('.dr-nates-lab__result--success')
    await expect(done).toContainText('Resurrected as', { timeout: 10000 })
    await demo.step(page, "follows RESURRECT: Dr. Nate's Secret Lab restores it")
    await demo.show(done)

    await demo.click(done.locator('.dr-nates-lab__node-link'))
    await expect(page.locator('body')).toContainText(title, { timeout: 10000 })
    await expect(page.locator('body')).toContainText(text)
    await demo.step(page, 'opens the restored draft')
    await demo.show(page.getByText(text).first())
  }, { cleanup })
})

/**
 * A deleted node whose type no longer exists can be looked at but not brought back (#4717).
 *
 * Setup (harness): a tomb copy of a document whose nodetype is gone, the way old copies of
 * retired types sit in the prod tomb (the type's own copy is there too, which gives its name).
 * The admin opens its coffin and sees the stored text with the reason in place of RESURRECT;
 * asking the Lab for it directly gives the same reason. Cleanup removes both tomb rows.
 */
test('a deleted node whose type no longer exists is view-only in The Node Crypt', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const admin = await demo.actor(browser, 'e2e_admin (admin)', '#38495e')
  const { page } = admin
  const stamp = Date.now()
  const title = `Crypt relic ${stamp}`
  const typeName = `oldtype${stamp % 100000}`
  const text = `Written for a type that is long gone ${stamp}.`
  const reason = `Its type, ${typeName}, no longer exists.`
  let relicId = null

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -MData::Dumper -e '${code}'`

  const cleanup = async () => {
    if (!relicId) return
    await demo.shell(
      admin,
      `docker exec e2devdb mysql -u root -pblah everything -e "DELETE FROM tomb WHERE node_id IN (${relicId}, ${relicId + 1}); DELETE FROM node WHERE node_id=${relicId}" 2>/dev/null`,
      'removes the test copies from the tomb'
    )
  }

  await demo.scenario('node-crypt-retired-type', [admin], async () => {
    await loginAsE2EAdmin(page)
    // A narrow desktop (the recording size), where the content column is tight beside the sidebar.
    const viewport = page.viewportSize()
    if (viewport && viewport.width > 900) await page.setViewportSize({ width: 900, height: viewport.height })

    const planted = await demo.shell(
      admin,
      perl(
        'initEverything; my $root = $DB->getNode("root", "user"); ' +
          'my $id = $DB->sqlSelect("GREATEST(MAX(node_id), (SELECT MAX(node_id) FROM tomb))", "node") + 2000000 + int(rand(100000)) * 2; ' +
          'my %row = (author_user => $root->{node_id}, killa_user => $root->{node_id}, createtime => "2009-05-13 12:52:11"); ' +
          `$DB->sqlInsert("tomb", { %row, node_id => $id + 1, type_nodetype => 1, title => "${typeName}", data => Dumper({ title => "${typeName}" }) }); ` +
          `$DB->sqlInsert("tomb", { %row, node_id => $id, type_nodetype => $id + 1, title => "${title}", data => Dumper({ title => "${title}", doctext => "${text}" }) }); ` +
          'print $id'
      ),
      `stores a deleted document whose type, ${typeName}, no longer exists`,
      { result: (o) => `node ${o.trim()}` }
    )
    relicId = Number(String(planted).trim())
    expect(relicId).toBeGreaterThan(0)

    await page.goto('/title/The%20Node%20Crypt')
    const entry = page.locator('.node-crypt__list-table a', { hasText: title })
    await expect(entry).toHaveCount(1, { timeout: 10000 })
    // The list stays inside the content column (long unbroken titles once pushed it under the sidebar).
    const overhang = await page.evaluate(() => {
      const table = document.querySelector('.node-crypt__list-table')
      const column = document.querySelector('#mainbody')
      return column ? table.getBoundingClientRect().right - column.getBoundingClientRect().right : 0
    })
    expect(overhang).toBeLessThanOrEqual(1)
    await demo.step(page, 'opens The Node Crypt and finds the deleted document')
    await demo.show(entry)

    await demo.click(entry)
    const coffin = page.locator('.node-crypt__coffin-table')
    await expect(coffin).toBeVisible({ timeout: 10000 })
    await expect(coffin.locator('tr', { hasText: 'doctext' })).toContainText(text)
    const refusal = page.locator('.node-crypt__refusal')
    await expect(refusal).toHaveText(`This node can't be resurrected. ${reason}`)
    await expect(page.locator('.node-crypt__heading a', { hasText: 'RESURRECT' })).toHaveCount(0)
    await demo.step(page, 'opens its coffin: the stored copy is there, with why it cannot come back')
    await demo.show(refusal)

    await page.goto(`/title/Dr.%20Nate%27s%20Secret%20Lab?olde2nodeid=${relicId}`)
    const refused = page.locator('.dr-nates-lab__result--error')
    await expect(refused).toContainText(`Node ${relicId} can't be resurrected. ${reason}`, { timeout: 10000 })
    await demo.step(page, "asks Dr. Nate's Secret Lab for it anyway: the Lab gives the same reason")
    await demo.show(refused)

    await page.goto('/title/The%20Node%20Crypt')
    await expect(page.locator('.node-crypt__list-table a', { hasText: title })).toHaveCount(1, { timeout: 10000 })
    await demo.step(page, 'the stored copy is still in the Crypt')
    await demo.show(page.locator('.node-crypt__list-table a', { hasText: title }))
  }, { cleanup })
})
