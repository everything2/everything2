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

    const title = `BackLink ${Date.now()}`
    const disc = await (await page.request.post('/api/debatecomments/action/create', {
      data: { title, restricted: GODS },
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

      // Clicking it lands on the discussions page, filtered to the group. The page is a pure
      // gate (#4543-era): React reads show_ug off the URL and fetches /api/usergroup_discussions.
      const listCall = page.waitForResponse((r) => r.url().includes('/api/usergroup_discussions'))
      await back.click()
      const list = await listCall
      expect(new URL(page.url()).searchParams.get('show_ug')).toBe(String(GODS))
      expect(new URL(list.url()).searchParams.get('show_ug')).toBe(String(GODS))
      expect(Number((await list.json()).selected_usergroup)).toBe(GODS)

      // What the viewer sees: gods is the active group, and the new discussion is listed.
      const active = page.locator('.ug-discussions__usergroup-link--active')
      await expect(active).toHaveCount(1)
      await expect(active).toHaveAttribute('href', `?show_ug=${GODS}`)
      await expect(page.getByText(title).first()).toBeVisible()
    } finally {
      await page.request.post(`/api/debatecomments/${discId}/action/delete`).catch(() => {})
    }
  })
})
