const { test, expect } = require('@playwright/test')
const demo = require('./fixtures/demo')

/**
 * The Atom feeds a feed reader subscribes to: New Writeups (advertised in every page's <head>),
 * one author's New Writeups, and the Cool Archive. Each is served as application/atom+xml, parses
 * as XML, and carries entries.
 * Watch: `./tools/e2e-demo.sh atom-feeds`.
 */

// Load a feed the way a reader would and parse it in the browser.
async function readFeed(page, url) {
  const res = await page.goto(url)
  expect(res.status()).toBe(200)
  expect(res.headers()['content-type']).toContain('application/atom+xml')
  const xml = await res.text()
  return page.evaluate((x) => {
    const d = new DOMParser().parseFromString(x, 'application/xml')
    const err = d.getElementsByTagName('parsererror')[0]
    const all = (tag) => Array.from(d.getElementsByTagName(tag))
    return {
      error: err ? err.textContent : null,
      root: d.documentElement.nodeName,
      title: (all('title')[0] || {}).textContent,
      entries: all('entry').length,
      authors: all('entry').map((e) => (e.getElementsByTagName('name')[0] || {}).textContent),
    }
  }, xml)
}

test('a feed reader can subscribe to the Atom feeds', async ({ browser }) => {
  test.setTimeout(demo.DEMO ? 180000 : 60000)
  const reader = await demo.actor(browser, 'feed reader (signed out)', '#38495e')
  const { page } = reader

  await demo.scenario('atom-feeds', [reader], async () => {
    await page.goto('/')
    await demo.step(page, 'visits the front page, which advertises its Atom feed')
    const link = page.locator('link[rel="alternate"][type="application/atom+xml"]')
    await expect(link).toHaveCount(1, { timeout: 10000 })
    const href = await link.getAttribute('href')
    expect(href).toContain('New+Writeups+Atom+Feed')

    await demo.step(page, 'opens the New Writeups feed')
    const latest = await readFeed(page, href)
    expect(latest.error).toBeNull()
    expect(latest.root).toBe('feed')
    expect(latest.title).toBe('Everything2 New Writeups')
    expect(latest.entries).toBeGreaterThan(0)
    await demo.show(page.locator('body'))

    await demo.step(page, "opens root's own New Writeups feed")
    const mine = await readFeed(page, '/node/ticker/New+Writeups+Atom+Feed?foruser=root')
    expect(mine.error).toBeNull()
    expect(mine.title).toBe("root's New Writeups")
    expect(mine.entries).toBeGreaterThan(0)
    expect(mine.authors.every((a) => a === 'root')).toBeTruthy()
    await demo.show(page.locator('body'))

    await demo.step(page, 'opens the Cool Archive feed')
    const cool = await readFeed(page, '/node/ticker/Cool+Archive+Atom+Feed')
    expect(cool.error).toBeNull()
    expect(cool.title).toBe('Everything2 Cool Archive')
    expect(cool.entries).toBeGreaterThan(0)
    await demo.show(page.locator('body'))
  })
})
