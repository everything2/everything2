/**
 * url-routing.spec.js
 *
 * Structural URL-shape routing parity: validate EACH URL type the app must
 * honour, so a regression in either dispatcher -- Apache mod_rewrite (mod_perl)
 * or app.psgi's _recover_route_params_from_request_uri (PSGI/Starman) -- is
 * caught here rather than by a user clicking a link.
 *
 * Every shape below was either a real regression during the PSGI migration or a
 * route the old Apache rewrites handled and the PSGI proxy had to reproduce:
 *   - /node/<id>, /node/<id>/<displaytype>      numeric permalinks
 *   - /title/, /e2node/, /node/<type>/<title>   title routes
 *   - /user/, /user/<u>/writeups                user routes
 *   - /?node_id=, /?node=, /index.pl?node_id=   query-string forms
 *   - canonical 303 redirect (e2node by id + lastnode_id -> /title/)  [the
 *     "blank page" bug: the redirect was silently dropped under PSGI]
 *   - /s/<short>  302 short-URL,  /stylesheet/<v> 307,  /health JSON,
 *     /robots.txt, /sitemap proxy, /favicon.ico
 */

const { test, expect } = require('@playwright/test')

const ANCHOR_SUPERDOC = 'Cool Archive'   // renders directly, never redirects
const ANCHOR_E2NODE = 'good poetry'       // e2node: by-id + lastnode_id => 303 canonical

// Read a node's own id out of the server-rendered JSON bootstrap so the suite
// survives a reseed that renumbers nodes.
async function discoverNodeId(page, title) {
  const response = await page.goto(`/title/${encodeURIComponent(title)}`)
  expect(response.ok(), `/title/${title} responded ${response.status()}`).toBe(true)
  const m = (await page.content()).match(/"node":\{[^}]*?"node_id":"?(\d+)"?/)
  expect(m, `could not find node_id in the "${title}" page bootstrap`).not.toBeNull()
  return m[1]
}

const FRONT_PAGE = /<title>\s*Welcome to Everything\s*<\/title>/i
const FINDINGS = /Here's the stuff we found when you searched/i

test.describe('URL-shape routing parity (mod_perl ⇄ PSGI)', () => {
  // ---- A) page-render shapes: must land on the node, not front page / Findings ----
  test('renders for every title/node/user/query shape', async ({ page }) => {
    const sid = await discoverNodeId(page, ANCHOR_SUPERDOC)

    const shapes = [
      `/node/${sid}`,
      `/node/${sid}?lastnode_id=0`,           // superdoc: no redirect, renders
      `/title/${encodeURIComponent(ANCHOR_SUPERDOC)}`,
      `/e2node/${encodeURIComponent(ANCHOR_SUPERDOC)}`,
      `/node/${encodeURIComponent(ANCHOR_SUPERDOC)}`,           // node/<title>
      `/node/superdoc/${encodeURIComponent(ANCHOR_SUPERDOC)}`,  // node/<type>/<title>
      `/?node_id=${sid}`,                      // query form, by id
      `/?node=${encodeURIComponent(ANCHOR_SUPERDOC)}`,          // query form, by name
      `/index.pl?node_id=${sid}`,              // legacy index.pl
    ]
    for (const url of shapes) {
      const resp = await page.goto(url)
      expect(resp.ok(), `${url} responded ${resp.status()}`).toBe(true)
      const body = await page.content()
      expect(body, `${url} fell through to the front page`).not.toMatch(FRONT_PAGE)
      expect(body, `${url} bounced to Findings`).not.toMatch(FINDINGS)
      expect(body, `${url} did not render "${ANCHOR_SUPERDOC}"`).toContain(ANCHOR_SUPERDOC)
    }
  })

  test('/user/<name> and /user/<u>/writeups resolve', async ({ page }) => {
    let resp = await page.goto('/user/root')
    expect(resp.ok()).toBe(true)
    expect(await page.content()).toContain('root')

    resp = await page.goto('/user/root/writeups')
    expect(resp.ok()).toBe(true)
    expect(await page.content(), 'writeups search did not render').toMatch(/User Search|writeups/i)
  })

  test('/node/<id>/<displaytype> serves the XML variant', async ({ page }) => {
    // NB: the xmltrue displaytype was retired (b2069643d "Remove xmltrue type and
    // dead htmlcodes"); assert the live `xml` variant instead. Still exercises the
    // /node/<id>/<displaytype> path-form routing parity this block is about.
    const id = await discoverNodeId(page, 'writeup with bad cool info')
    const resp = await page.request.get(`/node/${id}/xml`)
    expect(resp.ok()).toBe(true)
    expect(await resp.text(), 'xml displaytype did not produce XML').toMatch(/<\?xml|<NODE>/i)
  })

  // ---- B) redirect shapes: assert the exact status + Location (no following) ----
  test('canonical 303: e2node by id + lastnode_id redirects to /title/ (the blank-page bug)', async ({ page }) => {
    const id = await discoverNodeId(page, ANCHOR_E2NODE)

    // All three by-id forms must 303 to the canonical title URL. Under PSGI this
    // silently produced an empty 200 before the fix (CGI redirect() return was
    // discarded; only mod_perl's $r side-effect emitted it).
    for (const url of [`/?node_id=${id}&lastnode_id=0`, `/node/${id}?lastnode_id=0`, `/index.pl?node_id=${id}&lastnode_id=0`]) {
      const resp = await page.request.get(url, { maxRedirects: 0 })
      expect(resp.status(), `${url} should 303`).toBe(303)
      expect(resp.headers()['location'], `${url} Location`).toMatch(/\/title\/good\+poetry/)
    }

    // Sanity: the SAME e2node without lastnode_id renders (no redirect).
    const direct = await page.request.get(`/?node_id=${id}`, { maxRedirects: 0 })
    expect(direct.status(), 'no-lastnode should render, not redirect').toBe(200)
    expect((await direct.body()).length, 'render must be non-empty').toBeGreaterThan(1000)
  })

  test('/s/<short> 302s to the target node', async ({ page }) => {
    // Encode a known node id to its base-49 short string (same charset as the Page).
    const sid = await discoverNodeId(page, ANCHOR_SUPERDOC)
    const C = 'acdefhkmnorstuwxzABCDEFGHJKLMNPQRTUVWXYZ234789'.split('')
    let n = parseInt(sid, 10), s = ''
    while (n > 0) { s = C[n % C.length] + s; n = Math.floor(n / C.length) }

    const resp = await page.request.get(`/s/${s}`, { maxRedirects: 0 })
    expect(resp.status(), `/s/${s} should 302`).toBe(302)
    // Location is the node's canonical_url, e.g. /node/superdoc/Cool%20Archive
    // (space as %20 / + / literal depending on encoding) -- match loosely.
    expect(resp.headers()['location'], 'short-url target').toMatch(/Cool(%20|\+| )Archive/)
  })

  test('/stylesheet/<name>_v<N>.css 307s to the unversioned css', async ({ page }) => {
    const resp = await page.request.get('/stylesheet/zen_v9.css', { maxRedirects: 0 })
    expect(resp.status(), 'versioned stylesheet should 307').toBe(307)
    expect(resp.headers()['location']).toMatch(/\/stylesheet\/zen\.css$/)
  })

  // ---- C) endpoint shapes: health, robots, sitemap, favicon, static ----
  test('/health and /health.pl return the health JSON (not the app shell)', async ({ page }) => {
    for (const u of ['/health', '/health.pl']) {
      const resp = await page.request.get(u)
      expect(resp.ok(), `${u} responded ${resp.status()}`).toBe(true)
      const json = JSON.parse(await resp.text())
      expect(json.status, `${u} status field`).toBe('ok')
    }
  })

  test('/robots.txt advertises the Sitemap directive', async ({ page }) => {
    const resp = await page.request.get('/robots.txt')
    expect(resp.ok()).toBe(true)
    expect(await resp.text()).toMatch(/^\s*Sitemap:\s*\S+/im)
  })

  // Both sitemap entry points must reach the S3 bucket and return REAL sitemap
  // XML -- not the app shell, and not an S3 error. The old assertion only checked
  // "not the app shell", so an S3 NoSuchBucket/WebsiteRedirect error page passed
  // it: under PSGI the vhost's `ProxyPreserveHost On` leaked into the [P] sitemap
  // proxy (sent Host: everything2.com -> NoSuchBucket), and `/sitemap.xml` (a
  // sibling file, not under /sitemap/) slipped past the ProxyPass exclusion and
  // rendered the front page. Assert positively on sitemap content so either
  // regression fails here.
  for (const path of ['/sitemap/index.xml', '/sitemap.xml']) {
    test(`${path} returns real S3 sitemap XML (not the app shell, not an S3 error)`, async ({ page }) => {
      const resp = await page.request.get(path)
      expect(resp.status(), `${path} status`).toBe(200)
      expect(resp.headers()['content-type'] || '', `${path} content-type`).toMatch(/xml/i)
      const body = await resp.text()
      expect(body, `${path} not swallowed by the app`).not.toMatch(/Welcome to Everything|Here's the stuff we found/i)
      expect(body, `${path} hit an S3 error (wrong Host?)`).not.toMatch(/NoSuchBucket|WebsiteRedirect|bucket name/i)
      expect(body, `${path} is not a sitemap`).toMatch(/<sitemapindex|<urlset|<loc>/i)
    })
  }

  test('/favicon.ico is served as an image, not the app', async ({ page }) => {
    const resp = await page.request.get('/favicon.ico')
    expect(resp.ok()).toBe(true)
    expect(resp.headers()['content-type'] || '', 'favicon content-type').toMatch(/image|icon|octet-stream/i)
  })

  // Unimplemented/legacy display types (crawlers still hit ?displaytype=listnodelets,
  // shownodelet, etc.) must degrade to the default 'display' view, NOT 500 with
  // "Can't locate object method '<displaytype>'" from HTMLRouter::route_node.
  for (const dt of ['listnodelets', 'shownodelet', 'nonexistent_displaytype_xyz']) {
    test(`?displaytype=${dt} degrades to a 200 render, not a 500`, async ({ page }) => {
      const resp = await page.request.get(`/title/${encodeURIComponent(ANCHOR_SUPERDOC)}?displaytype=${dt}`)
      expect(resp.status(), `displaytype=${dt} should not 5xx`).toBe(200)
      const body = await resp.text()
      expect(body, `displaytype=${dt} leaked a die`).not.toMatch(/Can't locate object method|wrapper caught a die/i)
      expect(body, `displaytype=${dt} did not render the node`).toContain(ANCHOR_SUPERDOC)
    })
  }
})
