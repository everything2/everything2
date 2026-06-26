const { test, expect } = require('@playwright/test')
const { visitAsGuest } = require('./fixtures/auth')

// Guest chrome safety net (#4371). The guest fast-path serves the page-independent chrome
// from the build-keyed `guestchrome` cache and builds only per-node content fresh. These
// tests assert the full guest chrome both RENDERS and is present in the `window.e2` blob the
// server hydrated -- so a single nodelet/feed silently dropping out of the cached chrome is
// caught, not just gross "page is blank" breakage. (coolnodes/staffpicks were unclassified
// and would have been dropped by the cache before #4371 -- this guards that regression.)

// Site-wide feeds that live in the cached chrome -- present (as arrays) for every guest.
const CHROME_FEED_KEYS = ['newWriteups', 'coolnodes', 'staffpicks']
// Other always-present chrome keys (presence-checked, since some are legitimately falsy, e.g. 0).
const CHROME_KEYS = ['user', 'lastCommit', 'architecture', 'use_local_assets']

function assertGuestChrome(e2) {
  expect(e2, 'window.e2 present').toBeTruthy()
  expect(e2.guest, 'e2.guest flag set for a guest').toBeTruthy()
  for (const key of CHROME_FEED_KEYS) {
    expect(Array.isArray(e2[key]), `chrome feed '${key}' is an array in the blob`).toBe(true)
  }
  for (const key of CHROME_KEYS) {
    expect(e2[key] !== undefined && e2[key] !== null, `chrome key '${key}' present`).toBe(true)
  }
}

test.describe('Guest chrome', () => {
  test('front page renders the full guest chrome', async ({ page }) => {
    await visitAsGuest(page) // GET / as a logged-out guest

    await expect(page.locator('#e2-react-page-root')).toBeVisible()
    // Sign In nodelet (guest identity chrome)
    await expect(page.locator('#signin_user')).toBeVisible()
    await expect(page.locator('#signin_passwd')).toBeVisible()
    // New Writeups nodelet is populated
    expect(
      await page.locator('#new_writeups a.title').count(),
      'New Writeups nodelet has title links',
    ).toBeGreaterThan(0)

    // The blob the server hydrated -- a missing key here means a feed/nodelet vanished
    // from the cached chrome.
    assertGuestChrome(await page.evaluate(() => window.e2))
  })

  test('guest content node carries cached chrome + fresh node content', async ({ page }) => {
    // A non-React node exercises the hydration fast-path: cached chrome + per-node content built fresh.
    const resp = await page.goto('/title/tomato')
    expect(resp.ok(), `guest e2node responded ${resp.status()}`).toBe(true)
    await expect(page.locator('#e2-react-page-root')).toBeVisible()

    const e2 = await page.evaluate(() => window.e2)
    assertGuestChrome(e2) // chrome served from cache
    // per-node content built fresh
    expect(e2.title, 'title content present').toBeTruthy()
    expect(e2.node_id, 'node_id content present').toBeTruthy()
    expect(e2.node && e2.node.title, 'node.title content present').toBeTruthy()
  })
})
