const { test, expect } = require('@playwright/test')
const { loginAsE2EAdmin } = require('./fixtures/auth')

/**
 * Discussion "back to <group> discussions" link.
 *
 * On a debate/debatecomment node, the header link back to the usergroup's
 * discussions must carry the group filter (show_ug=<usergroup node_id>) so the
 * destination is pre-filtered to that group, not the viewer's whole discussion
 * set. Verified by an actual click + asserting the landed page filtered to the
 * group.
 */
const GODS = 114

test.describe('Discussion back-link', () => {
  test('back-link carries the group filter and lands on the filtered discussions page', async ({ page }) => {
    await loginAsE2EAdmin(page)

    const disc = await (await page.request.post('/api/debatecomments/action/create', {
      data: { title: `BackLink ${Date.now()}`, restricted: GODS },
    })).json()
    expect(disc.success).toBe(1)
    const discId = disc.node_id

    try {
      await page.goto(`/node/${discId}`)

      const back = page.getByRole('link', { name: /back to .* discussions/i })
      await back.waitFor({ timeout: 10000 })

      // The href itself carries the group filter.
      const href = await back.getAttribute('href')
      expect(href).toContain(`show_ug=${GODS}`)

      // Clicking it lands on the discussions page, filtered to the group.
      await back.click()
      await page.waitForLoadState('load')

      const blob = (await page.content()).match(/<script id="nodeinfojson">e2 = (\{.*?\})<\/script>/s)
      const cd = blob ? (JSON.parse(blob[1]).contentData || {}) : {}
      expect(cd.type).toBe('usergroup_discussions')
      expect(Number(cd.selected_usergroup)).toBe(GODS)
    } finally {
      await page.request.post(`/api/debatecomments/${discId}/action/delete`).catch(() => {})
    }
  })
})
