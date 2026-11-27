const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Literal square brackets survive the editor (#4756).
 *
 * E2 stores a literal "[" or "]" as &#91; / &#93; so it isn't read as a [link]. Every editor has
 * to turn those into protected bracket marks when it loads content, or saving writes them back as
 * plain brackets and they become a live link. The usergroup description editor stands in for the
 * editors that loaded content without that step: an admin opens the description, saves it
 * unchanged (once straight after opening, once after switching to HTML and back to rich), and the
 * page still shows the literal brackets as text, next to the real link.
 *
 * User: e2e_admin (admins manage any usergroup). Setup (harness): a usergroup, nuked afterwards.
 * Watch: `./tools/e2e-demo.sh editor-literal-brackets`.
 */
test('literal brackets in a usergroup description stay literal through the editor', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 90000)
  const admin = await demo.actor(browser, 'e2e_admin (manages the usergroup)', '#38495e')
  const { page } = admin
  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
  const group = `Bracket club ${stamp}`
  const description = '<p>Use &#91;square brackets&#93; for links, like [Everything2].</p>'
  let groupId

  const perl = (code) =>
    `docker exec e2devapp perl -I/var/everything/ecore -I/var/libraries/lib/perl5 -MEverything -e '${code}'`

  const cleanup = async () => {
    await demo.shell(admin, perl(
      'initEverything("development-docker"); ' +
      `my $id = $DB->sqlSelect("node_id", "node", "title=" . $DB->quote("${group}")) or exit; ` +
      '$DB->nukeNode($DB->getNodeById($id, "force"), -1, 1); $DB->sqlDelete("tomb", "node_id=$id")'
    ), 'removes the test usergroup')
  }

  // The rendered description: literal brackets as text, and only the real link is a link.
  const checkRendered = async (when) => {
    const body = page.locator('.usergroup-card-body .content').first()
    await body.scrollIntoViewIfNeeded({ timeout: 10000 }).catch(() => {})
    await expect(body, `${when}: the literal brackets show as text`).toContainText('Use [square brackets] for links', { timeout: 10000 })
    await expect(body.locator('a', { hasText: 'square brackets' }), `${when}: they are not a link`).toHaveCount(0)
    await expect(body.locator('a', { hasText: 'Everything2' }), `${when}: the real link is still a link`).toHaveCount(1)
    return body
  }
  const stored = async () => (await (await page.request.get(`/api/nodes/${groupId}`)).json()).doctext

  await demo.scenario('editor-literal-brackets', [admin], async () => {
    const out = await demo.shell(admin, perl(
      'initEverything("development-docker"); my $root = $DB->getNode("root", "user"); ' +
      `print $DB->insertNode("${group}", "usergroup", $root, {}, "skip maintenance")`
    ), `creates the usergroup "${group}"`, { result: (o) => `node ${o.trim()}` })
    groupId = parseInt(String(out).trim(), 10)
    expect(groupId).toBeGreaterThan(0)

    await loginAsE2EAdmin(page)
    const set = await (await page.request.post(`/api/usergroups/${groupId}/action/description`, { data: { doctext: description } })).json()
    expect(set.success).toBeTruthy()

    await demo.step(page, 'opens the usergroup: the description shows [square brackets] as text')
    await page.goto(`/node/${groupId}`)
    await demo.show(await checkRendered('before editing'))

    await demo.step(page, 'clicks Edit, then Save Description without changing anything')
    await demo.click(page.locator('.usergroup-edit-btn').first() /* the description's Edit; the members card has its own */)
    await expect(page.locator('.usergroup-description-editor .ProseMirror')).toContainText('square brackets', { timeout: 10000 })
    await demo.click(page.locator('.usergroup-description-editor__save-btn'))
    await expect(page.locator('.usergroup-description-editor')).toHaveCount(0, { timeout: 10000 })
    await page.reload()
    await demo.show(await checkRendered('after saving'))
    expect(await stored(), 'saved with the brackets still escaped').toContain('&#91;square brackets&#93;')

    await demo.step(page, 'edits again, switches to HTML and back to rich, and saves')
    await demo.click(page.locator('.usergroup-edit-btn').first() /* the description's Edit; the members card has its own */)
    const toggle = page.locator('.usergroup-description-editor .e2-mode-toggle')
    await demo.click(toggle)
    await expect(page.locator('.usergroup-description-editor__textarea')).toBeVisible({ timeout: 10000 })
    await demo.click(toggle)
    await expect(page.locator('.usergroup-description-editor .ProseMirror')).toContainText('square brackets', { timeout: 10000 })
    await demo.click(page.locator('.usergroup-description-editor__save-btn'))
    await expect(page.locator('.usergroup-description-editor')).toHaveCount(0, { timeout: 10000 })
    await page.reload()
    await demo.show(await checkRendered('after the mode switch'))
    expect(await stored(), 'saved with the brackets still escaped').toContain('&#91;square brackets&#93;')
  }, { cleanup })
})
