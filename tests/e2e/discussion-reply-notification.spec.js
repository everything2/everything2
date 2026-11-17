const { test, expect } = require('@playwright/test')
const { loginAsE2EEditor, loginAsE2EAdmin } = require('./fixtures/auth')
const demo = require('./fixtures/demo')
const { notificationsUI } = require('./fixtures/notifications')

/**
 * Cross-user "newcomment" notification, driven through the real UI (#4661).
 *
 * Two users in two independent browser sessions, in a Content Editors discussion:
 *   - e2e_editor (a CE member, not an admin) started it and is opted in to "new
 *     comment in one of my usergroup discussions";
 *   - both have already viewed pages (warm workers), then e2e_admin replies using
 *     the reply form, and the reply is in the thread;
 *   - e2e_editor's Notifications nodelet then shows "e2e_admin replied in
 *     <discussion>", and following it lands on the discussion with the reply;
 *   - the replier gets no notification for their own reply;
 *   - e2e_editor then replies in the thread themselves: although opted in, they get
 *     no notification for it, and the e2e_admin one is still the only entry.
 *
 * Only e2e_editor's notification preferences are changed: other specs drive root's
 * and e2e_admin's, and the preferences API replaces the whole map, so sharing a user
 * across parallel specs makes them clobber each other. That is also why the self-reply
 * case is shown with e2e_editor (opted in) rather than e2e_admin (not opted in, so it
 * would pass vacuously). t/225_notify_new_comment.t covers the same rule in Perl.
 *
 * Run as a plain test, or watch it: `./tools/e2e-demo.sh discussion-reply-notification`
 * records both sessions side by side (see fixtures/demo.js). With E2E_DEMO_DEVICE=mobile
 * both users are on phones, where notifications are behind the bottom nav's Notify button.
 */
const CONTENT_EDITORS = 923653
const NEWCOMMENT = 1930993           // the 'newcomment' notification node
const NOTIFICATIONS_NODELET = 1930708

async function ensureNotificationsNodelet(page) {
  const current = await (await page.request.get('/api/nodelets')).json()
  const ids = (current.nodelets || []).map(n => Number(n.node_id))
  if (!ids.includes(NOTIFICATIONS_NODELET)) {
    const resp = await page.request.post('/api/nodelets', {
      data: { nodelet_ids: [NOTIFICATIONS_NODELET, ...ids] },
    })
    expect((await resp.json()).success).toBeTruthy()
  }
  return ids
}

// Reply to the discussion through the real reply form, as `actor`, and wait until the
// thread (where the form redirects back to) lists the reply. "Be the first to reply"
// only shows on an empty thread; after that, Reply is in the discussion's header.
async function replyThroughForm(actor, discId, replyTitle, text) {
  const { page } = actor
  const firstReply = page.locator('.debate__start-reply-link')
  const headerReply = page.locator('.debate__actions .debate__action-link', { hasText: 'reply' })
  await demo.step(page, 'clicks Reply')
  await demo.click((await firstReply.count()) ? firstReply : headerReply)
  await page.waitForSelector('.dc-edit__form', { timeout: 10000 })

  await demo.step(page, 'writes the reply')
  await page.fill('.dc-edit__input', replyTitle)
  await page.locator('.dc-edit__editor-wrapper .ProseMirror').click()
  await page.keyboard.type(text, { delay: demo.DEMO ? 40 : 0 })

  await demo.step(page, 'posts it')
  const replyResponse = page.waitForResponse(r => /\/api\/debatecomments\/\d+\/action\/reply/.test(r.url()))
  await demo.click(page.locator('.dc-edit__save-btn'))
  const replyBody = await (await replyResponse).json()
  expect(replyBody.success).toBe(1)
  expect(replyBody.node_id).toBeTruthy()

  await page.waitForURL(new RegExp(`node_id=${discId}`))
  const thread = page.locator('.debate__replies')
  await expect(thread).toContainText(replyTitle)
  await demo.step(page, 'back on the thread: the reply is listed')
  await demo.show(thread)
}

async function setNewCommentPref(page, on) {
  const resp = await page.request.post('/api/preferences/notifications', {
    data: { notifications: on ? { [NEWCOMMENT]: 1 } : {} },
  })
  expect((await resp.json()).success).toBeTruthy()
}

test.describe('Discussion reply notification (cross-user, UI)', () => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)

  test('a reply notifies the other opted-in member, never the replier', async ({ browser }) => {
    const recipient = await demo.actor(browser, 'e2e_editor (recipient)', '#38495e')
    const replier = await demo.actor(browser, 'e2e_admin (replier)', '#2f6f8f')
    const title = `Reply notification check ${Date.now()}`
    const replyTitle = `re: ${title}`
    const selfReplyTitle = `thanks: ${title}`
    const originalNodelets = {}
    let discId

    const cleanup = async () => {
      // Deleting is admin-only (e2e_admin); deleting the discussion removes its replies.
      if (discId) {
        await replier.page.request.post(`/api/debatecomments/${discId}/action/delete`).catch(() => {})
      }
      await setNewCommentPref(recipient.page, false).catch(() => {})
      for (const a of [recipient, replier]) {
        const before = originalNodelets[a.label]
        if (before && !before.includes(NOTIFICATIONS_NODELET)) {
          await a.page.request.post('/api/nodelets', { data: { nodelet_ids: before } }).catch(() => {})
        }
      }
    }

    await demo.scenario('discussion-reply-notification', [recipient, replier], async () => {
      // --- Setup: both log in and show the Notifications nodelet; recipient opts in.
      await Promise.all([loginAsE2EEditor(recipient.page), loginAsE2EAdmin(replier.page)])
      for (const a of [recipient, replier]) {
        originalNodelets[a.label] = await ensureNotificationsNodelet(a.page)
      }
      await setNewCommentPref(recipient.page, true)

      // e2e_editor starts a Content Editors discussion (setup; the reply is under test).
      const created = await (await recipient.page.request.post('/api/debatecomments/action/create', {
        data: { title, restricted: CONTENT_EDITORS, doctext: '<p>Anyone around?</p>' },
      })).json()
      expect(created.success).toBe(1)
      discId = created.node_id

      await Promise.all([
        recipient.page.goto(`/?node_id=${discId}`),
        replier.page.goto(`/?node_id=${discId}`),
      ])
      await Promise.all([
        demo.step(recipient.page, 'started a Content Editors discussion; opted in to reply notifications'),
        demo.step(replier.page, 'opens the discussion'),
      ])
      const recipientNotes = notificationsUI(recipient)
      const replierNotes = notificationsUI(replier)
      await demo.show(recipientNotes.handle)

      // --- e2e_admin replies through the reply form. -------------------------------
      await replyThroughForm(replier, discId, replyTitle, 'Yes, I am here.')

      // --- e2e_editor sees the notification. ----------------------------------------
      await demo.step(recipient.page, 'reloads the page')
      await recipient.page.reload()
      await demo.step(recipient.page, 'opens notifications')
      await recipientNotes.open()
      const notice = recipientNotes.entries.filter({ hasText: `replied in ${title}` })
      await expect(notice).toHaveCount(1)
      await expect(notice).toContainText(`e2e_admin replied in ${title}`)
      await demo.step(recipient.page, 'Notifications: "e2e_admin replied in ..."')
      await demo.show(notice, 2500)

      await demo.step(recipient.page, 'follows the link to the discussion')
      await demo.click(notice.getByRole('link', { name: title }))
      const recipientThread = recipient.page.locator('.debate__replies')
      await expect(recipientThread).toContainText(replyTitle, { timeout: 15000 })
      await demo.step(recipient.page, 'on the discussion, with the reply')
      await demo.show(recipientThread)

      // --- e2e_admin is not notified about their own reply. -------------------------
      await demo.step(replier.page, 'reloads: nothing about their own reply')
      await replier.page.reload()
      await replierNotes.open()
      await expect(replierNotes.panel).toBeVisible()
      await expect(replierNotes.panel).not.toContainText(`replied in ${title}`)
      await demo.show(replierNotes.panel, 2500)

      // --- e2e_editor (opted in) replies too, and gets nothing for it. ------------
      await replyThroughForm(recipient, discId, selfReplyTitle, 'Thanks, see you there.')

      await demo.step(recipient.page, 'reloads: nothing about their own reply')
      await recipient.page.reload()
      await recipientNotes.open()
      // The earlier notification is still there (proves the list loaded), it's still
      // the only one for this discussion, and none names e2e_editor as the replier.
      const stillOne = recipientNotes.entries.filter({ hasText: `replied in ${title}` })
      await expect(stillOne).toHaveCount(1)
      await expect(stillOne).toContainText(`e2e_admin replied in ${title}`)
      await expect(recipientNotes.panel).not.toContainText(`e2e_editor replied in`)
      await demo.show(stillOne, 2500)
    }, { cleanup })
  })
})
