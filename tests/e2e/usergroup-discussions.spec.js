const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Usergroup Discussions E2E
 *
 * Regression guard for discussion visibility. The htmlpage->API conversion
 * (252576b08) made create_debate pass root_debatecomment=0 in the insert
 * nodedata, which silently defeated the debate_create maintenance hook -- so a
 * new discussion landed with root_debatecomment=0 and was dropped from the
 * listing (usergroup_discussions GROUP BYs root_debatecomment then
 * getNodeById()s it; a 0 -> getNodeById(0) -> skipped).
 *
 * This test creates a discussion and asserts it actually shows up on the
 * Usergroup discussions page. Pre-fix it would NOT appear.
 *
 * TEST USER: e2e_admin (admin, pw test123). Member of gods (114), so show_ug=114
 * is a valid view and create_debate is permitted there.
 *
 * CLEANUP: the created discussion is deleted via the API in a finally block
 * (admins can delete).
 */
test.describe('Usergroup discussions', () => {
  test('a newly created discussion appears on the discussions page', async ({ page }) => {
    await loginAsE2EAdmin(page)

    const title = `E2E roottest discussion ${Date.now()}`
    let nodeId

    try {
      // Create the discussion via the API (gods=114; e2e_admin is a member).
      const resp = await page.request.post('/api/debatecomments/action/create', {
        data: { title, restricted: 114 },
      })
      expect(resp.ok()).toBe(true)
      const body = await resp.json()
      expect(body.success).toBe(1)
      nodeId = body.node_id
      expect(nodeId).toBeTruthy()

      // It must be listed on the Usergroup discussions superdoc (node 1977025).
      await page.goto('/node/1977025?show_ug=114')
      await expect(page.locator('.ug-discussions')).toContainText(title, { timeout: 10000 })
    } finally {
      if (nodeId) {
        await page.request
          .post(`/api/debatecomments/${nodeId}/action/delete`)
          .catch(() => {})
      }
    }
  })
})
