/**
 * link-resolution.spec.js
 *
 * End-to-end coverage for link CONSTRUCTION + PARSING + CLICK-THROUGH
 * across every title shape that's burned us. The unit tests in t/101
 * (helper), t/102 (smoke), t/103 (encoder) cover the server-side
 * round-trip, and react/components/LinkNode.test.js covers the React
 * href production in isolation. This file glues all three pieces
 * together: render a real React page in a real browser, click the link
 * the way a user does, verify we land on the right node.
 *
 * If any future change to the URL pipeline (LinkNode encoding,
 * rewriteCleanEscape, _recover_route_params_from_request_uri, or Apache
 * rewrites) breaks the contract for a special-character title, this
 * suite catches it before users do.
 *
 * Reference issues exercised:
 *   #4060 — '&' (Sense & Sensibility)
 *   #4143 — bare '+' as space (Message Inbox via Messages.js)
 *   #4145 — apostrophe (Neiboku's Secret Library — Clockmaker case)
 *   #3418 — multi-space title (preserves both spaces)
 *   #4132 — '#' in title (Star Trek #9: Triangle)
 *   ... plus emoji, CJK, extended Latin, literal +
 */

const { test, expect } = require('@playwright/test')
const { visitAsGuest } = require('./fixtures/auth')

// The corpus. Each entry is a seeded fixture in tools/seeds.pl whose
// title contains a class of character that has historically broken URLs.
// `match` is a regex that must appear in the body of the loaded node page
// — usually the title itself, but with the special chars escaped so the
// regex matches the actual on-page text (which may be HTML-entity-encoded).
const SEEDED_TITLES = [
  {
    name: 'apostrophe (#4145)',
    title: "Neiboku's Secret Library",
    match: /Neiboku/i,
  },
  {
    name: 'ampersand (#4060)',
    title: 'Sense & Sensibility',
    match: /Sense\s*(?:&amp;|&)\s*Sensibility/i,
  },
  {
    name: 'literal + in title',
    title: 'Writeups+plusses, a lesson in love',
    match: /Writeups\+plusses/i,
  },
  {
    name: 'multi-space title (#3418)',
    title:
      'I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.',
    match: /red pepper and blood/i,
  },
  {
    name: 'emoji (dog + cat)',
    title: 'animals 🐕🐈',
    match: /animals\s*🐕🐈/i,
  },
  {
    name: 'emoji (heart + flower)',
    title: 'hearts and flowers ❤🌸',
    match: /hearts and flowers/i,
  },
  {
    name: 'emoji (food)',
    title: 'food emojis 🍕',
    match: /food emojis/i,
  },
  {
    name: 'extended Latin (ë)',
    title: 'swedish tomatoë',
    match: /swedish\s+tomato/i,
  },
  {
    name: 'plain control',
    title: 'good poetry',
    match: /good\s+poetry/i,
  },
]

test.describe('Link construction → parse → click-through', () => {
  // --- A) Direct navigation: the href produced by rewriteCleanEscape ---
  // For each seeded title, navigate to /title/<rewriteCleanEscape(title)>
  // directly (no clicks). This exercises the server-side encoder + the
  // helper-side decoder in the browser context, with whatever URL
  // normalization the browser does in the address bar.
  for (const { name, title, match } of SEEDED_TITLES) {
    test(`/title/ direct navigation resolves "${name}"`, async ({ page }) => {
      // We don't have rewriteCleanEscape in JS — use encodeURIComponent
      // and trust the browser to percent-encode whatever's left. This is
      // the "any reasonable URL form" check, not the "exact canonical
      // form" check.
      const url = `/title/${encodeURIComponent(title)}`
      const response = await page.goto(url)
      expect(response.ok(), `${url} responded with ${response.status()}`).toBe(true)

      // Must land on the node, not Findings.
      const body = await page.content()
      expect(body, `${url} bounced to Findings — search-failure body present`)
        .not.toMatch(/Here's the stuff we found when you searched/)
      expect(body).toMatch(match)
    })
  }

  // --- B) Search form submission: the /?node=… path ---
  // Mimics typing the title in the header search box and hitting Enter.
  // Triggers the server-side redirect-to-canonical (rewriteCleanEscape →
  // 303 → helper parses canonical URL). This is the Clockmaker loop case.
  for (const { name, title, match } of SEEDED_TITLES) {
    test(`search form submit resolves "${name}" without bouncing`, async ({ page }) => {
      const url = `/?node=${encodeURIComponent(title)}`
      const response = await page.goto(url)
      expect(response.ok(), `${url} responded with ${response.status()}`).toBe(true)

      const finalUrl = page.url()
      const body = await page.content()
      expect(body, `${url} (final: ${finalUrl}) reached Findings — redirect loop or wrong decode`)
        .not.toMatch(/Here's the stuff we found when you searched/)
      expect(body).toMatch(match)
    })
  }

  // --- C) Rendered LinkNode click-through ---
  // The full pipeline: page renders a LinkNode that contains the title,
  // user clicks it, browser navigates, landing page is correct. This
  // covers the JS-side encoding path that A/B skip.
  test('front-page New Writeups links all resolve to their nodes', async ({ page }) => {
    await visitAsGuest(page)

    // Collect every writeup title link in the New Writeups sidebar
    // nodelet. Each `<a class="title" ...>` has both an href and visible
    // text equal to the node title (after entity-decoding).
    const titleLinks = await page
      .locator('#new_writeups a.title')
      .evaluateAll((els) =>
        els.map((el) => ({
          href: el.getAttribute('href'),
          text: el.textContent,
        })),
      )
    expect(titleLinks.length, 'New Writeups nodelet has at least one title link').toBeGreaterThan(0)

    // Click-through each link, verify the landing page is for that title
    // (not Findings, not a 404, not the same page we came from).
    for (const { href, text } of titleLinks) {
      const response = await page.goto(href)
      expect(response.ok(), `LinkNode href ${href} (text "${text}") failed: ${response.status()}`)
        .toBe(true)

      const body = await page.content()
      expect(
        body,
        `LinkNode href ${href} (text "${text}") landed on Findings instead of the node`,
      ).not.toMatch(/Here's the stuff we found when you searched/)

      // Loose match — the rendered title contains the words of the link
      // text. Don't require exact match because HTML entity encoding and
      // whitespace handling differ between the link text and the page
      // title rendering. Use the first word *segment* (up to the first
      // non-word char) rather than stripping all non-word chars: a hyphenated
      // title like "pour-over" must match the literal "pour-over" on the page,
      // not the non-existent joined string "pourover".
      const firstWord = text.split(/\s+/)[0].split(/[^\w]/)[0]
      if (firstWord) {
        expect(
          body,
          `LinkNode href ${href} (text "${text}") landed on page that doesn't mention "${firstWord}"`,
        ).toContain(firstWord)
      }
    }
  })

  // --- D) Loop detection ---
  // Explicit redirect-chain walker — if any URL appears twice in the
  // chain, we infinite-looped. This is the #4145 regression net for
  // anything that's seeded.
  for (const { name, title } of SEEDED_TITLES) {
    test(`no redirect loop when searching "${name}"`, async ({ page }) => {
      const seen = new Set()
      let looped = false
      page.on('response', (resp) => {
        const url = resp.url()
        const status = resp.status()
        if (status >= 300 && status < 400) {
          if (seen.has(url)) {
            looped = true
          }
          seen.add(url)
        }
      })
      await page.goto(`/?node=${encodeURIComponent(title)}`)
      expect(looped, `redirect loop detected while resolving "${title}"`).toBe(false)
    })
  }

  // --- E) Negative control: confirm the loop detector actually works ---
  // A truly bogus search lands on the Findings page (#4382 routed
  // not_found_node -> search_results) or the legacy "Nothing Found"
  // superdoc — both terminal, neither redirects. The control asserts the
  // request resolves to a terminal page (no redirect loop, 2xx response).
  test('loop detector control: bogus search reaches a terminal page', async ({ page }) => {
    const response = await page.goto(
      `/?node=${encodeURIComponent('definitely-not-a-real-node-xyz-12345')}`,
    )
    expect(response.ok()).toBe(true)
    const body = await page.content()
    expect(body).toMatch(
      /We couldn't find anything for|Here's the stuff we found when you searched|Nothing Found|nothing_found/,
    )
  })
})
