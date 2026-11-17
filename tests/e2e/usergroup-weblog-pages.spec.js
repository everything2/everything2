const { test, expect } = require('@playwright/test')
const { loginAs, loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * Usergroup weblog pages show posted documents with their E2 formatting and links.
 *
 *   - News for Noders: a document posted to the News weblog appears on the page with
 *     its formatting, and its [link] goes to the linked node.
 *   - Clientdev Home: genericdev (a clientdev member) posts a document to the clientdev
 *     weblog through the "Add to Page" modal; it then appears on Clientdev Home with
 *     its formatting and a working [link].
 *
 * Each scenario is a single user. Fixture documents are created through the API by an
 * e2e_admin session that isn't recorded (documents are Content Editors/admin-only), and
 * cleanup removes the weblog entries and deletes the documents.
 *
 * Watch it: `./tools/e2e-demo.sh usergroup-weblog-pages` (E2E_DEMO_DEVICE=mobile for phones).
 */
const NEWS_PAGE = 165580          // "News for noders. Stuff that matters."
const NEWS_GROUP = 2175734        // News usergroup
const CLIENTDEV_PAGE = 2144912    // "Clientdev Home"
const CLIENTDEV_GROUP = 1199641   // clientdev usergroup
const LINKED = 'historical origins of the beverage'   // an e2node in the dev seed

// A document with E2 markup: some formatting and an internal [link].
async function createDocument(page, title, lead) {
  const created = await (await page.request.post('/api/node/create', { data: { type: 'document', title } })).json()
  expect(created.success).toBe(1)
  const doctext = `<p>${lead} <strong>bold news</strong> and <em>some detail</em>. Background: [${LINKED}].</p>`
  const updated = await (await page.request.post(`/api/documents/${created.node_id}`, { data: { doctext } })).json()
  expect(updated.success).toBeTruthy()
  return created.node_id
}

async function removeDocument(page, groupId, docId) {
  if (!docId) return
  await page.request.delete(`/api/weblog/${groupId}/${docId}`).catch(() => {})
  await page.request.post(`/api/nodes/${docId}/action/delete`).catch(() => {})
}

// The entry on a weblog page: rendered formatting, and a link that leads to the node.
async function checkEntry(actor, entry, contentSelector) {
  const content = entry.locator(contentSelector)
  await expect(content.locator('strong')).toHaveText('bold news')
  await expect(content.locator('em')).toHaveText('some detail')
  const link = content.getByRole('link', { name: LINKED })
  await expect(link).toHaveAttribute('href', /\/title\/historical(%20| )origins/)
  await demo.step(actor.page, 'the post shows with its formatting and links')
  await demo.show(entry, 2500)

  await demo.step(actor.page, `follows the [${LINKED}] link`)
  await demo.click(link)
  await expect(actor.page.locator('#pageheader, h1').first()).toContainText(LINKED, { timeout: 10000 })
  await demo.step(actor.page, 'on the linked node')
  await demo.show(actor.page.locator('#pageheader, h1').first())
}

test.describe('Usergroup weblog pages', () => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)

  test('News for Noders shows a posted document with its formatting and links', async ({ browser }) => {
    const reader = await demo.actor(browser, 'e2e_admin', '#38495e')
    const title = `Weblog news check ${Date.now()}`
    let docId

    await demo.scenario('news-for-noders', [reader], async () => {
      await loginAsE2EAdmin(reader.page)
      // Setup: a document, posted to the News weblog.
      docId = await createDocument(reader.page, title, 'Announcing')
      const posted = await (await reader.page.request.post(`/api/weblog/${NEWS_GROUP}`, { data: { to_node: docId } })).json()
      expect(posted.success).toBe(1)

      await demo.step(reader.page, 'opens News for Noders')
      await reader.page.goto(`/?node_id=${NEWS_PAGE}`)
      const entry = reader.page.locator('.news-for-noders__entry', { hasText: title })
      await expect(entry).toHaveCount(1, { timeout: 10000 })
      await checkEntry(reader, entry, '.news-for-noders__content')
    }, { cleanup: () => removeDocument(reader.page, NEWS_GROUP, docId) })
  })

  test('Clientdev Home shows a document a member posted to its weblog', async ({ browser }) => {
    const member = await demo.actor(browser, 'genericdev (clientdev member)', '#2f6f8f')
    // Unrecorded admin session: creates the fixture document and cleans up.
    const adminCtx = await browser.newContext()
    const admin = await adminCtx.newPage()
    const title = `Weblog clientdev check ${Date.now()}`
    let docId

    const cleanup = async () => {
      await removeDocument(admin, CLIENTDEV_GROUP, docId)
      await adminCtx.close()
    }

    await demo.scenario('clientdev-home-weblog', [member], async () => {
      await Promise.all([loginAs(member.page, 'genericdev', 'blah'), loginAsE2EAdmin(admin)])
      docId = await createDocument(admin, title, 'Client release:')

      await demo.step(member.page, 'opens the document')
      await member.page.goto(`/?node_id=${docId}`)
      await demo.step(member.page, 'clicks Add to Page')
      await demo.click(member.page.locator('button[title="Add to usergroup page"]'))
      const modal = member.page.locator('.modal-compact')
      const select = modal.locator('select.modal-compact__select')
      await expect(select.locator(`option[value="${CLIENTDEV_GROUP}"]`)).toHaveCount(1, { timeout: 10000 })
      await demo.step(member.page, 'picks clientdev and posts')
      await select.selectOption(String(CLIENTDEV_GROUP))
      const postResponse = member.page.waitForResponse(r => r.url().includes(`/api/weblog/${CLIENTDEV_GROUP}`) && r.request().method() === 'POST')
      await demo.click(modal.locator('button.modal-compact__btn'))
      expect((await (await postResponse).json()).success).toBe(1)

      await demo.step(member.page, 'opens Clientdev Home')
      await member.page.goto(`/?node_id=${CLIENTDEV_PAGE}`)
      const entry = member.page.locator('.clientdev-home__weblog > div', { hasText: title })
      await expect(entry).toHaveCount(1, { timeout: 10000 })
      await checkEntry(member, entry, '.clientdev-home__content')
    }, { cleanup })
  })
})
