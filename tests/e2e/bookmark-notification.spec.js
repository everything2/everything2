const { test, expect } = require('@playwright/test')
const { loginAsE2EUser, loginAsE2EAdmin } = require('./fixtures/auth')
const { createWriteup } = require('./fixtures/content')

/**
 * Cross-user bookmark notification.
 *
 * Bookmarking a writeup notifies the author -- but via a Cool Man Eddie private
 * message, NOT the notification system (see Everything::API::cool::_notify_bookmark
 * and t/149_bookmark_notify). So this verifies the author receives a CME message
 * referencing the writeup. Built on a freshly-published writeup so it's repeatable.
 */
test.describe('Notification delivery (bookmark)', () => {
  test('bookmarking a writeup messages its author via Cool Man Eddie', async ({ browser }) => {
    const authorCtx = await browser.newContext()
    const actorCtx = await browser.newContext()
    const author = await authorCtx.newPage()
    const actor = await actorCtx.newPage()
    const title = `E2E bookmark target ${Date.now()}`
    let writeupId

    try {
      // Author publishes a writeup.
      await loginAsE2EUser(author)
      ;({ writeupId } = await createWriteup(author, { title }))

      // A different user bookmarks it.
      await loginAsE2EAdmin(actor)
      const bm = await actor.request.post(`/api/cool/bookmark/${writeupId}`)
      expect(bm.ok()).toBe(true)
      const bmBody = await bm.json()
      expect(bmBody.success).toBeTruthy()

      // The author receives a Cool Man Eddie message referencing the writeup.
      const msgs = await author.request.get('/api/messages/')
      expect(msgs.ok()).toBe(true)
      const msgText = await msgs.text()
      expect(msgText).toContain(title)
      expect(msgText).toContain('Cool Man Eddie')
    } finally {
      await authorCtx.close()
      await actorCtx.close()
    }
  })
})
