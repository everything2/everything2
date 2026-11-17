const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Discussion threading (object model).
 *
 * A reply is a debatecomment whose parent_debatecomment is the comment replied to
 * and whose root_debatecomment is the THREAD root (the top-level discussion). It
 * is inserted into its parent's nodegroup. This verifies the reply node is
 * created and surfaces under its thread.
 *
 * Uses gods (114), of which e2e_admin is a member, so create/view/reply are all
 * permitted.
 */
const GODS = 114

test.describe('Discussion threading', () => {
  test('a reply is created and surfaces under its discussion thread', async ({ page }) => {
    await loginAsE2EAdmin(page)

    const discTitle = `E2E thread ${Date.now()}`
    const replyMarker = `reply-marker-${Date.now()}`
    let discId, replyId

    try {
      // Top-level discussion.
      const disc = await (await page.request.post('/api/debatecomments/action/create', {
        data: { title: discTitle, restricted: GODS },
      })).json()
      expect(disc.success).toBe(1)
      discId = disc.node_id
      expect(discId).toBeTruthy()

      // Reply to it.
      const reply = await (await page.request.post(`/api/debatecomments/${discId}/action/reply`, {
        data: { title: `re: ${discTitle}`, doctext: `<p>${replyMarker}</p>` },
      })).json()
      expect(reply.success).toBe(1)
      replyId = reply.node_id
      expect(replyId).toBeTruthy()
      expect(replyId).not.toBe(discId) // a distinct node, not the discussion itself

      // The reply is a real, addressable node (its page renders)...
      const replyView = await page.request.get(`/node/${replyId}`)
      expect(replyView.ok()).toBe(true)

      // ...and it surfaces under its thread on the discussion page. (This used to be skipped
      // as "stale cached nodegroup"; the real causes were fixed in #4661 and #4687.
      // Replies between non-admin members: discussion-member-reply.spec.js.)
      await page.goto(`/node/${discId}`)
      const thread = page.locator('.debate__replies')
      await expect(thread).toContainText(`re: ${discTitle}`, { timeout: 10000 })
      await expect(thread).toContainText(replyMarker)
    } finally {
      // children first
      for (const id of [replyId, discId].filter(Boolean)) {
        await page.request.post(`/api/debatecomments/${id}/action/delete`).catch(() => {})
      }
    }
  })
})
