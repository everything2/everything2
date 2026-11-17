const { test, expect } = require('@playwright/test')
const { loginAs, loginAsE2EEditor, loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')

/**
 * A reply between two ordinary usergroup members shows up in the thread (#4687).
 *
 * Both users are Content Editors members and neither is an admin (the gods group is all
 * admins, which used to hide this):
 *   - genericeditor starts a Content Editors discussion (setup, through the API);
 *   - both have viewed pages first (warm workers);
 *   - e2e_editor replies to it through the reply form;
 *   - after reloading, the reply is in the thread for both of them.
 *
 * Deleting discussions is admin-only, so an e2e_admin session that isn't recorded cleans up.
 * Watch it: `./tools/e2e-demo.sh discussion-member-reply` (side by side; E2E_DEMO_DEVICE=mobile too).
 */
const CONTENT_EDITORS = 923653

test('a reply from one ordinary member to another shows in the thread for both', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const starter = await demo.actor(browser, 'genericeditor (started it)', '#38495e')
  const replier = await demo.actor(browser, 'e2e_editor (replies)', '#2f6f8f')
  const adminCtx = await browser.newContext()
  const admin = await adminCtx.newPage()
  const title = `Member reply check ${Date.now()}`
  const replyTitle = `re: ${title}`
  let discId

  const cleanup = async () => {
    if (discId) await admin.request.post(`/api/debatecomments/${discId}/action/delete`).catch(() => {})
    await adminCtx.close()
  }

  await demo.scenario('discussion-member-reply', [starter, replier], async () => {
    await Promise.all([
      loginAs(starter.page, 'genericeditor', 'blah'),
      loginAsE2EEditor(replier.page),
      loginAsE2EAdmin(admin),
    ])

    const created = await (await starter.page.request.post('/api/debatecomments/action/create', {
      data: { title, restricted: CONTENT_EDITORS, doctext: '<p>Thoughts, editors?</p>' },
    })).json()
    expect(created.success).toBe(1)
    discId = created.node_id

    await Promise.all([starter.page.goto(`/?node_id=${discId}`), replier.page.goto(`/?node_id=${discId}`)])
    await Promise.all([
      demo.step(starter.page, 'started a Content Editors discussion'),
      demo.step(replier.page, 'opens the discussion'),
    ])

    // e2e_editor replies through the form.
    await demo.step(replier.page, 'clicks Reply')
    await demo.click(replier.page.locator('.debate__start-reply-link'))
    await replier.page.waitForSelector('.dc-edit__form', { timeout: 10000 })
    await demo.step(replier.page, 'writes the reply')
    await replier.page.fill('.dc-edit__input', replyTitle)
    await replier.page.locator('.dc-edit__editor-wrapper .ProseMirror').click()
    await replier.page.keyboard.type('Here are mine.', { delay: demo.DEMO ? 40 : 0 })
    await demo.step(replier.page, 'posts it')
    const replyResponse = replier.page.waitForResponse((r) => /\/api\/debatecomments\/\d+\/action\/reply/.test(r.url()))
    await demo.click(replier.page.locator('.dc-edit__save-btn'))
    const reply = await (await replyResponse).json()
    expect(reply.success).toBe(1)

    // Both reload: the reply is in the thread.
    for (const [who, caption] of [[replier, 'reloads: their reply is in the thread'], [starter, 'reloads: the reply is in the thread']]) {
      await who.page.goto(`/?node_id=${discId}`)
      const thread = who.page.locator('.debate__replies')
      await expect(thread).toContainText(replyTitle, { timeout: 10000 })
      await demo.step(who.page, caption)
      await demo.show(thread, 2500)
    }
  }, { cleanup })
})
