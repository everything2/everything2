const { test, expect } = require('@playwright/test')
const { loginAsRoot, loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Cross-user notification delivery E2E.
 *
 * The full pipeline: a recipient opts into a notification type, a DIFFERENT user
 * performs the triggering action, and the recipient then sees the notification.
 *
 * Covers 'newdiscussion' (Everything::Application::notify_new_discussion, called
 * from the debatecomments create API). This is the type that regressed -- the old
 * debate_create maintenance hook detected API-vs-form via !$query, unreliable
 * under PSGI, so nobody was notified.
 *
 * The two users run in separate browser contexts (independent sessions) so we
 * don't have to log a single session in and out.
 *
 * Recipient: root (a member of the Content Editors notification set).
 * Actor:     e2e_admin (admin, may start a CE discussion; != root so not skipped).
 *
 * Isolation: the discussion node_id is unique per run and the assertion matches
 * the notification to it, so repeated runs don't interfere. Cleanup deletes the
 * discussion.
 */

const NEWDISCUSSION_ID = 1980269   // the 'newdiscussion' notification node
const CONTENT_EDITORS  = 923653    // usergroup; root is in its notification set

test.describe('Notification delivery (cross-user)', () => {
  test('newdiscussion: another user starting a discussion notifies a subscribed member', async ({ browser }) => {
    const recipientCtx = await browser.newContext()
    const actorCtx = await browser.newContext()
    const recipient = await recipientCtx.newPage()
    const actor = await actorCtx.newPage()
    const title = `E2E notify discussion ${Date.now()}`
    let nodeId

    try {
      // 1. Recipient (root) opts into the newdiscussion notification.
      await loginAsRoot(recipient)
      const prefResp = await recipient.request.post('/api/preferences/notifications', {
        data: { notifications: { [NEWDISCUSSION_ID]: 1 } },
      })
      expect(prefResp.ok()).toBe(true)

      // 2. A different user (e2e_admin) starts a discussion in a group the recipient belongs to.
      await loginAsE2EAdmin(actor)
      const createResp = await actor.request.post('/api/debatecomments/action/create', {
        data: { title, restricted: CONTENT_EDITORS },
      })
      expect(createResp.ok()).toBe(true)
      const created = await createResp.json()
      expect(created.success).toBe(1)
      nodeId = created.node_id
      expect(nodeId).toBeTruthy()

      // 3. The recipient now sees a notification referencing this discussion. The
      // rendered text is "New discussion post: [<title>]", so match the unique title.
      const notifResp = await recipient.request.get('/api/notifications/')
      expect(notifResp.ok()).toBe(true)
      const notifText = await notifResp.text()
      expect(notifText).toContain(title)
    } finally {
      if (nodeId) {
        await actor.request.post(`/api/debatecomments/${nodeId}/action/delete`).catch(() => {})
      }
      await recipientCtx.close()
      await actorCtx.close()
    }
  })
})
