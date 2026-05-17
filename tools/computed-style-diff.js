#!/usr/bin/env node

/**
 * Computed-Style Diff Tool
 *
 * Captures computed CSS styles for every visible element across a matrix of
 * pages × themes × viewports, saves to JSON snapshots, and diffs two snapshots
 * to find meaningful visual drift. Built to validate refactors that should
 * produce identical visual output (e.g. inline-styles → BEM CSS classes).
 *
 * Workflow for verifying the inline-styles → BEM refactor:
 *
 *   1. Snapshot the working tree state (refactor applied):
 *        node tools/computed-style-diff.js capture --label working-tree
 *
 *   2. Stash/checkout HEAD, rebuild the container:
 *        git stash
 *        ./docker/devbuild.sh --skip-tests
 *
 *   3. Snapshot HEAD state (pre-refactor):
 *        node tools/computed-style-diff.js capture --label HEAD
 *
 *   4. Restore working tree, rebuild:
 *        git stash pop
 *        ./docker/devbuild.sh --skip-tests
 *
 *   5. Diff the two snapshots:
 *        node tools/computed-style-diff.js compare HEAD working-tree
 *
 * Snapshots live in screenshots/computed-styles/{label}.json
 *
 * Usage:
 *   capture     Snapshot computed styles for the configured page matrix
 *   compare     Diff two snapshots, report meaningful drift
 *   list        List existing snapshots
 *   delete      Remove a snapshot
 *
 *   --label NAME       Snapshot label (required for capture)
 *   --quick            Use a 6-page subset instead of full sweep
 *   --themes 1973976,1965235  Comma-separated theme IDs (default: a representative subset)
 *   --all-themes       Use all 16 themes (slow)
 *   --viewports mobile,desktop   Default: both
 *   --user USERNAME    Capture as authenticated user (default: e2e_user for auth pages)
 *   --pages PATH1,PATH2  Override the default page list
 *   --tolerance PX     Tolerance for size differences in px (default: 1)
 *   --json             Compare: emit raw JSON instead of human report
 *   --max-issues N     Compare: cap reported issues per page (default: 50)
 */

const puppeteer = require('puppeteer')
const fs = require('fs')
const path = require('path')

const DEV_URL = 'http://development.everything2.com:9080'
const SNAPSHOT_DIR = path.join(__dirname, '..', 'screenshots', 'computed-styles')

const VIEWPORTS = {
  mobile: { width: 375, height: 812, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desktop: { width: 1280, height: 1024, deviceScaleFactor: 1, isMobile: false, hasTouch: false },
}

const MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'

const TEST_USERS = {
  root: { password: 'blah' },
  e2e_admin: { password: 'test123' },
  e2e_editor: { password: 'test123' },
  e2e_user: { password: 'test123' },
}

// Default theme subset chosen for visual coverage:
// - basesheet (1973976) is the dominant carrier of BEM classes added in the refactor
// - Kernel Blue (1882070) is the default zensheet, lost 46 lines in the refactor
// - Understatement (1965235), Mikoyan25 (1926437), Bookworm (1928497) cover the major theme families
const DEFAULT_THEMES = [
  { id: 1973976, name: 'basesheet' },
  { id: 1882070, name: 'Kernel Blue' },
  { id: 1965235, name: 'Understatement' },
  { id: 1926437, name: 'mikoyan25' },
  { id: 1928497, name: 'bookworm' },
]

const ALL_THEMES = [
  { id: 1973976, name: 'basesheet' },
  { id: 1882070, name: 'Kernel Blue' },
  { id: 1965286, name: 'Bare Understatement' },
  { id: 1928497, name: 'bookworm' },
  { id: 1926578, name: 'Cool understatement' },
  { id: 1996378, name: 'Deep Ice' },
  { id: 1997697, name: 'dim jukka emulation' },
  { id: 1997552, name: 'e2gle' },
  { id: 1905818, name: 'Gunpowder Green' },
  { id: 1926437, name: 'mikoyan25' },
  { id: 1951961, name: 'mikoyan25 flipped' },
  { id: 1983570, name: 'mikoyan25 light' },
  { id: 1965449, name: 'Monochrome understatement' },
  { id: 2029380, name: 'Pamphleteer' },
  { id: 2041900, name: 'Simplicity' },
  { id: 1965235, name: 'Understatement' },
  { id: 1946242, name: 'Warm understatement' },
]

// Pages chosen to exercise the components touched by the inline-styles refactor.
// Heavy bias toward Documents/* since that's where 200+ files were modified.
const SWEEP_PAGES = [
  { name: 'front-page', url: '/' },
  { name: 'e2node', url: '/title/tomato' },
  { name: 'writeup', url: '/node/2212929' },
  { name: 'user-homenode', url: '/user/root' },
  { name: 'category', url: '/title/Coffee+Culture' },
  { name: 'login', url: '/title/login' },
  { name: 'signup', url: '/title/Sign+up' },
  { name: 'cool-archive', url: '/title/Cool+Archive' },
  { name: 'document-directory', url: '/title/Everything+Document+Directory' },
  { name: 'most-wanted', url: '/title/Everything%27s+Most+Wanted' },
  { name: 'statistics', url: '/title/Everything+Statistics' },
  { name: 'achievements', url: '/title/My+Achievements', auth: true },
  { name: 'settings', url: '/title/Settings', auth: true },
  { name: 'message-inbox', url: '/title/Message+Inbox', auth: true },
  { name: 'drafts', url: '/title/Drafts', auth: true },
  { name: 'alphabetizer', url: '/title/alphabetizer' },
  { name: 'gift-shop', url: '/title/E2+Gift+Shop' },
  { name: 'poll-directory', url: '/title/Everything+Poll+Directory' },
  { name: 'sign-up-form', url: '/title/Sign+Up' },
  { name: 'text-formatter', url: '/title/Text+Formatter' },
]

const QUICK_PAGES = SWEEP_PAGES.slice(0, 6)

// Computed style properties we capture and diff. Layout + visual identity, no
// animation/transition fluff. Border individual sides included because shorthand
// expansion isn't always lossless in getComputedStyle.
const TRACKED_PROPS = [
  'display', 'position', 'visibility', 'opacity',
  'width', 'height', 'min-width', 'min-height', 'max-width', 'max-height',
  'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
  'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
  'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
  'border-top-color', 'border-right-color', 'border-bottom-color', 'border-left-color',
  'border-top-style', 'border-right-style', 'border-bottom-style', 'border-left-style',
  'border-radius',
  'color', 'background-color', 'background-image',
  'font-size', 'font-family', 'font-weight', 'font-style', 'line-height',
  'text-align', 'text-decoration-line', 'text-transform', 'letter-spacing',
  'box-sizing', 'overflow-x', 'overflow-y',
  'flex-direction', 'flex-wrap', 'justify-content', 'align-items', 'gap',
  'grid-template-columns', 'grid-template-rows',
  'top', 'right', 'bottom', 'left', 'z-index',
]

// Properties that may diff harmlessly. Color/font-family normalization is in
// the diff phase since it's value comparison rather than property selection.
const SIZE_PROPS = new Set([
  'width', 'height', 'min-width', 'min-height', 'max-width', 'max-height',
  'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
  'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
  'border-top-width', 'border-right-width', 'border-bottom-width', 'border-left-width',
  'top', 'right', 'bottom', 'left', 'gap', 'letter-spacing',
  'font-size', 'line-height', 'border-radius',
])

const COLOR_PROPS = new Set([
  'color', 'background-color',
  'border-top-color', 'border-right-color', 'border-bottom-color', 'border-left-color',
])

// ─── Auth helpers ──────────────────────────────────────────────────────────

async function loginUser(browser, username) {
  const user = TEST_USERS[username]
  if (!user) throw new Error(`Unknown test user: ${username}`)

  const page = await browser.newPage()
  await page.setViewport({ width: 1280, height: 1024 })
  await page.goto(DEV_URL, { waitUntil: 'networkidle0', timeout: 15000 })

  await page.waitForFunction(() => {
    const headers = Array.from(document.querySelectorAll('h2'))
    return headers.some(h => h.textContent.includes('Sign In'))
  }, { timeout: 5000 })

  const signInHeader = await page.evaluateHandle(() => {
    const headers = Array.from(document.querySelectorAll('h2'))
    return headers.find(h => h.textContent.includes('Sign In'))
  })

  if (signInHeader) {
    const isCollapsed = await page.evaluate(el =>
      el && (el.className.includes('is-closed') || el.getAttribute('aria-expanded') === 'false'),
      signInHeader
    )
    if (isCollapsed) {
      await signInHeader.click()
      await new Promise(r => setTimeout(r, 500))
    }
  }

  await page.waitForSelector('#signin_user', { visible: true, timeout: 5000 })
  await page.type('#signin_user', username)
  await page.type('#signin_passwd', user.password)
  await page.click('button[type="submit"]')
  await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 })
  await page.waitForFunction(() => window.e2 && window.e2.user && !window.e2.user.guest, { timeout: 15000 })

  const cookies = await page.cookies()
  await page.close()
  return cookies
}

async function setTheme(page, themeId) {
  await page.setCookie({
    name: 'userstyle',
    value: String(themeId),
    domain: 'development.everything2.com',
    path: '/',
  })
}

// ─── Capture ───────────────────────────────────────────────────────────────

async function capturePage(page, pageInfo) {
  const fullUrl = `${DEV_URL}${pageInfo.url}`
  await page.goto(fullUrl, { waitUntil: 'networkidle0', timeout: 30000 })

  // Wait for React lazy-loaded components to settle.
  await page.waitForFunction(() => {
    const root = document.querySelector('#e2-react-page-root')
    return !root || !root.textContent.includes('Loading...')
  }, { timeout: 10000 }).catch(() => {})

  await new Promise(r => setTimeout(r, 800))

  // Walk the DOM and extract tracked computed styles per element.
  // Identify elements by their stable DOM path so we can match them across snapshots
  // even when class names differ (which is the whole point of this refactor).
  return await page.evaluate((trackedProps) => {
    function pathOf(el) {
      const segments = []
      let cur = el
      while (cur && cur.nodeType === 1 && cur !== document.documentElement) {
        const parent = cur.parentElement
        if (!parent) { segments.unshift(cur.tagName.toLowerCase()); break }
        const sameTag = Array.from(parent.children).filter(c => c.tagName === cur.tagName)
        const idx = sameTag.indexOf(cur)
        segments.unshift(`${cur.tagName.toLowerCase()}[${idx}]`)
        cur = parent
      }
      return '/' + segments.join('/')
    }

    function isVisible(el) {
      const s = getComputedStyle(el)
      if (s.display === 'none' || s.visibility === 'hidden') return false
      const r = el.getBoundingClientRect()
      return r.width > 0 || r.height > 0
    }

    // Skip noise: scripts, dynamic content containers that won't match across snapshots.
    function shouldSkip(el) {
      const tag = el.tagName.toLowerCase()
      if (['script', 'style', 'meta', 'link', 'noscript', 'br', 'wbr'].includes(tag)) return true
      // Skip Google ads and reCAPTCHA — third-party iframes/widgets jitter between renders
      if (el.id && (el.id.startsWith('google_') || el.id.includes('recaptcha'))) return true
      if (el.className && typeof el.className === 'string') {
        if (/grecaptcha|adsbygoogle|advert[_-]google|iframe[_-]ad/i.test(el.className)) return true
      }
      // Skip elements positioned far offscreen (common ad-hiding pattern, jitters by px)
      const r = el.getBoundingClientRect()
      if (r.y < -5000 || r.x < -5000) return true
      // Skip iframe contents (third-party, may not be inspectable anyway)
      if (tag === 'iframe') return true
      return false
    }

    const elements = []
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT)
    let node
    while ((node = walker.nextNode())) {
      if (shouldSkip(node)) continue
      if (!isVisible(node)) continue
      const styles = getComputedStyle(node)
      const captured = {}
      for (const prop of trackedProps) {
        captured[prop] = styles.getPropertyValue(prop)
      }
      const rect = node.getBoundingClientRect()
      elements.push({
        path: pathOf(node),
        tag: node.tagName.toLowerCase(),
        id: node.id || null,
        className: (typeof node.className === 'string' ? node.className : null),
        textPreview: (node.textContent || '').trim().substring(0, 40),
        rect: {
          x: Math.round(rect.x), y: Math.round(rect.y),
          width: Math.round(rect.width), height: Math.round(rect.height),
        },
        styles: captured,
      })
    }
    return {
      url: location.pathname + location.search,
      title: document.title,
      bodyScrollWidth: document.body.scrollWidth,
      bodyScrollHeight: document.body.scrollHeight,
      elementCount: elements.length,
      elements,
    }
  }, TRACKED_PROPS)
}

async function runCapture(opts) {
  const { label, themes, viewports, pageList, user } = opts

  if (!fs.existsSync(SNAPSHOT_DIR)) fs.mkdirSync(SNAPSHOT_DIR, { recursive: true })
  const outputPath = path.join(SNAPSHOT_DIR, `${label}.json`)

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
  })

  const snapshot = {
    label,
    capturedAt: new Date().toISOString(),
    config: {
      themes: themes.map(t => t.id),
      viewports,
      pages: pageList.map(p => p.url),
      user: user || null,
    },
    captures: {},
  }

  try {
    let authCookies = null
    if (user) {
      console.log(`Logging in as ${user}...`)
      authCookies = await loginUser(browser, user)
    }

    // Lazy-login for auth pages if user not specified.
    let lazyAuthCookies = null
    async function getAuthCookies() {
      if (authCookies) return authCookies
      if (lazyAuthCookies) return lazyAuthCookies
      console.log('  (auth-only page) logging in as e2e_user for auth-only pages...')
      lazyAuthCookies = await loginUser(browser, 'e2e_user')
      return lazyAuthCookies
    }

    let total = themes.length * viewports.length * pageList.length
    let done = 0

    for (const theme of themes) {
      for (const viewportName of viewports) {
        for (const pageInfo of pageList) {
          done++
          const key = `${theme.id}|${viewportName}|${pageInfo.name}`
          process.stdout.write(`\r[${done}/${total}] ${theme.name} / ${viewportName} / ${pageInfo.name}${' '.repeat(20)}`)

          const page = await browser.newPage()
          await page.setViewport(VIEWPORTS[viewportName])
          if (viewportName === 'mobile') await page.setUserAgent(MOBILE_UA)

          const cookiesToUse = pageInfo.auth ? await getAuthCookies() : authCookies
          if (cookiesToUse) await page.setCookie(...cookiesToUse)
          await setTheme(page, theme.id)

          try {
            const data = await capturePage(page, pageInfo)
            data.theme = theme.name
            data.themeId = theme.id
            data.viewport = viewportName
            data.pageName = pageInfo.name
            snapshot.captures[key] = data
          } catch (err) {
            snapshot.captures[key] = { error: err.message, theme: theme.name, viewport: viewportName, pageName: pageInfo.name }
            process.stdout.write(`\n  ERROR: ${pageInfo.url} → ${err.message}\n`)
          }

          await page.close()
        }
      }
    }

    process.stdout.write('\n')
    fs.writeFileSync(outputPath, JSON.stringify(snapshot, null, 2))
    console.log(`Snapshot saved: ${outputPath}`)

    const successCount = Object.values(snapshot.captures).filter(c => !c.error).length
    const errCount = Object.values(snapshot.captures).filter(c => c.error).length
    const totalElements = Object.values(snapshot.captures).reduce((n, c) => n + (c.elementCount || 0), 0)
    console.log(`Captures: ${successCount} success, ${errCount} errors, ${totalElements} elements total`)
  } finally {
    await browser.close()
  }
}

// ─── Diff ──────────────────────────────────────────────────────────────────

function parsePxValue(v) {
  if (typeof v !== 'string') return null
  const m = v.match(/^(-?\d+(?:\.\d+)?)px$/)
  return m ? parseFloat(m[1]) : null
}

function normalizeColor(v) {
  if (typeof v !== 'string') return v
  // rgb(0, 0, 0) ↔ rgba(0, 0, 0, 1) — collapse to canonical form
  return v.replace(/\s+/g, '').toLowerCase()
}

function isMeaningfulDiff(prop, before, after, tolerancePx) {
  if (before === after) return false
  if (!before || !after) return { kind: 'presence', before, after }

  if (SIZE_PROPS.has(prop)) {
    const a = parsePxValue(before)
    const b = parsePxValue(after)
    if (a !== null && b !== null) {
      if (Math.abs(a - b) <= tolerancePx) return false
      return { kind: 'size', before, after, delta: +(b - a).toFixed(2) }
    }
  }

  if (COLOR_PROPS.has(prop)) {
    if (normalizeColor(before) === normalizeColor(after)) return false
    return { kind: 'color', before, after }
  }

  if (prop === 'font-family') {
    // Browsers may quote font names differently
    const norm = s => s.replace(/['"\s]/g, '').toLowerCase()
    if (norm(before) === norm(after)) return false
    return { kind: 'font', before, after }
  }

  return { kind: 'value', before, after }
}

function diffSnapshots(before, after, opts) {
  const { tolerancePx, maxIssues } = opts
  const results = []

  const allKeys = new Set([
    ...Object.keys(before.captures),
    ...Object.keys(after.captures),
  ])

  for (const key of allKeys) {
    const b = before.captures[key]
    const a = after.captures[key]

    if (!b || !a) {
      results.push({ key, missingIn: !b ? before.label : after.label })
      continue
    }
    if (b.error || a.error) {
      results.push({ key, error: { before: b.error, after: a.error } })
      continue
    }

    const result = {
      key,
      theme: a.theme, viewport: a.viewport, pageName: a.pageName,
      elementCountBefore: b.elementCount,
      elementCountAfter: a.elementCount,
      pageScrollDiff: {
        widthBefore: b.bodyScrollWidth, widthAfter: a.bodyScrollWidth,
        heightBefore: b.bodyScrollHeight, heightAfter: a.bodyScrollHeight,
      },
      elementDiffs: [],
      onlyInBefore: 0,
      onlyInAfter: 0,
    }

    // Index by path
    const bByPath = new Map(b.elements.map(e => [e.path, e]))
    const aByPath = new Map(a.elements.map(e => [e.path, e]))

    for (const [path, bEl] of bByPath) {
      const aEl = aByPath.get(path)
      if (!aEl) {
        result.onlyInBefore++
        continue
      }
      const propDiffs = {}
      let hasDiff = false
      for (const prop of TRACKED_PROPS) {
        const d = isMeaningfulDiff(prop, bEl.styles[prop], aEl.styles[prop], tolerancePx)
        if (d) {
          propDiffs[prop] = d
          hasDiff = true
        }
      }

      // Also check rect for layout shifts beyond tolerance
      const rectDiffs = {}
      for (const dim of ['x', 'y', 'width', 'height']) {
        const delta = aEl.rect[dim] - bEl.rect[dim]
        if (Math.abs(delta) > tolerancePx) {
          rectDiffs[dim] = { before: bEl.rect[dim], after: aEl.rect[dim], delta }
        }
      }

      if (hasDiff || Object.keys(rectDiffs).length > 0) {
        result.elementDiffs.push({
          path,
          tag: aEl.tag,
          id: aEl.id,
          className: aEl.className,
          textPreview: aEl.textPreview,
          propDiffs,
          rectDiffs: Object.keys(rectDiffs).length > 0 ? rectDiffs : undefined,
        })
      }
    }

    for (const [path] of aByPath) {
      if (!bByPath.has(path)) result.onlyInAfter++
    }

    // Sort by number of diffs descending
    result.elementDiffs.sort((x, y) =>
      Object.keys(y.propDiffs).length + (y.rectDiffs ? Object.keys(y.rectDiffs).length : 0)
      - Object.keys(x.propDiffs).length - (x.rectDiffs ? Object.keys(x.rectDiffs).length : 0)
    )

    if (result.elementDiffs.length > maxIssues) {
      result.elementDiffsTruncated = result.elementDiffs.length - maxIssues
      result.elementDiffs = result.elementDiffs.slice(0, maxIssues)
    }

    results.push(result)
  }

  return results
}

const COLORS = {
  red: '\x1b[31m', yellow: '\x1b[33m', green: '\x1b[32m',
  cyan: '\x1b[36m', dim: '\x1b[2m', bold: '\x1b[1m', reset: '\x1b[0m',
}

function printDiffReport(results) {
  console.log(`\n${'═'.repeat(70)}`)
  console.log(`${COLORS.bold}COMPUTED-STYLE DIFF REPORT${COLORS.reset}`)
  console.log(`${'═'.repeat(70)}`)

  let totalElementsDiffing = 0
  let totalCells = 0
  let cleanCells = 0

  for (const r of results) {
    totalCells++
    if (r.error || r.missingIn) continue
    if (r.elementDiffs.length === 0 && r.onlyInBefore === 0 && r.onlyInAfter === 0) {
      cleanCells++
      continue
    }
    totalElementsDiffing += r.elementDiffs.length
  }

  console.log(`\nMatrix cells (theme × viewport × page): ${totalCells}`)
  console.log(`Clean cells: ${COLORS.green}${cleanCells}${COLORS.reset} / ${totalCells}`)
  console.log(`Total element-level diffs: ${totalElementsDiffing}`)

  // Per-cell summary
  console.log(`\n${COLORS.bold}Per-cell summary (only cells with diffs):${COLORS.reset}`)
  for (const r of results) {
    if (r.error) {
      console.log(`  ${COLORS.red}ERR${COLORS.reset} ${r.key}  ${JSON.stringify(r.error)}`)
      continue
    }
    if (r.missingIn) {
      console.log(`  ${COLORS.yellow}MISS${COLORS.reset} ${r.key}  (only in ${r.missingIn === results[0]?.label ? 'before' : 'after'})`)
      continue
    }
    if (r.elementDiffs.length === 0 && r.onlyInBefore === 0 && r.onlyInAfter === 0) continue
    const elCountDelta = r.elementCountAfter - r.elementCountBefore
    console.log(`  ${r.theme} / ${r.viewport} / ${r.pageName}: ${COLORS.yellow}${r.elementDiffs.length}${COLORS.reset} elem diffs, ` +
      `${r.onlyInBefore}/${r.onlyInAfter} only-before/only-after, count Δ ${elCountDelta >= 0 ? '+' : ''}${elCountDelta}`)
  }

  // Detailed examples for top problem cells
  console.log(`\n${COLORS.bold}Top diffs (first 3 elements per cell, first 5 cells):${COLORS.reset}`)
  let cellsShown = 0
  for (const r of results) {
    if (r.error || r.missingIn || r.elementDiffs.length === 0) continue
    if (cellsShown >= 5) break
    cellsShown++
    console.log(`\n  ${COLORS.cyan}${r.theme} / ${r.viewport} / ${r.pageName}${COLORS.reset}`)
    for (const el of r.elementDiffs.slice(0, 3)) {
      const ident = el.id ? `#${el.id}` : (el.className ? `.${el.className.split(' ')[0]}` : '')
      console.log(`    <${el.tag}${ident}> ${COLORS.dim}${el.path}${COLORS.reset}`)
      if (el.textPreview) console.log(`      ${COLORS.dim}text: "${el.textPreview}"${COLORS.reset}`)
      const propEntries = Object.entries(el.propDiffs).slice(0, 5)
      for (const [prop, diff] of propEntries) {
        console.log(`      ${prop}: ${COLORS.dim}${diff.before}${COLORS.reset} → ${diff.after}` +
          (diff.delta !== undefined ? ` (Δ${diff.delta > 0 ? '+' : ''}${diff.delta}px)` : ''))
      }
      if (Object.keys(el.propDiffs).length > 5) {
        console.log(`      ${COLORS.dim}... and ${Object.keys(el.propDiffs).length - 5} more props${COLORS.reset}`)
      }
      if (el.rectDiffs) {
        for (const [dim, d] of Object.entries(el.rectDiffs)) {
          console.log(`      rect.${dim}: ${d.before}px → ${d.after}px (Δ${d.delta > 0 ? '+' : ''}${d.delta}px)`)
        }
      }
    }
    if (r.elementDiffs.length > 3) {
      console.log(`    ${COLORS.dim}... and ${r.elementDiffs.length - 3} more elements${COLORS.reset}`)
    }
  }

  // Most common drifting properties
  const propCounts = {}
  for (const r of results) {
    if (!r.elementDiffs) continue
    for (const el of r.elementDiffs) {
      for (const prop of Object.keys(el.propDiffs)) {
        propCounts[prop] = (propCounts[prop] || 0) + 1
      }
    }
  }
  if (Object.keys(propCounts).length > 0) {
    console.log(`\n${COLORS.bold}Most-drifting properties:${COLORS.reset}`)
    for (const [prop, n] of Object.entries(propCounts).sort((a, b) => b[1] - a[1]).slice(0, 15)) {
      console.log(`  ${prop}: ${n}`)
    }
  }

  console.log('')
}

// ─── CLI ───────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { _: [], flags: {} }
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]
    if (a.startsWith('--')) {
      const key = a.slice(2)
      const next = argv[i + 1]
      if (!next || next.startsWith('--')) {
        args.flags[key] = true
      } else {
        args.flags[key] = next
        i++
      }
    } else {
      args._.push(a)
    }
  }
  return args
}

async function main() {
  const argv = process.argv.slice(2)
  const args = parseArgs(argv)
  const cmd = args._[0]

  if (!cmd || args.flags.help) {
    console.log(`
Computed-Style Diff Tool

Commands:
  capture --label NAME [opts]   Snapshot computed styles
  compare BEFORE AFTER [opts]    Diff two snapshots
  list                           List existing snapshots
  delete LABEL                   Remove a snapshot

Capture options:
  --label NAME           Snapshot label (REQUIRED)
  --quick                6-page subset
  --themes ID1,ID2       Comma-separated theme IDs (default: 5 representative)
  --all-themes           All 16 themes (very slow)
  --viewports mobile,desktop   Default: both
  --user USERNAME        Capture as authenticated user
  --pages URL1,URL2      Override default page list

Compare options:
  --tolerance PX         Size diff tolerance (default: 1)
  --max-issues N         Cap reported issues per cell (default: 50)
  --json                 JSON output instead of human report

Recommended workflow for verifying the inline-styles → BEM refactor:
  1. node tools/computed-style-diff.js capture --label working-tree
  2. git stash && ./docker/devbuild.sh --skip-tests
  3. node tools/computed-style-diff.js capture --label HEAD
  4. git stash pop && ./docker/devbuild.sh --skip-tests
  5. node tools/computed-style-diff.js compare HEAD working-tree
`)
    process.exit(0)
  }

  if (cmd === 'list') {
    if (!fs.existsSync(SNAPSHOT_DIR)) { console.log('No snapshots.'); return }
    const files = fs.readdirSync(SNAPSHOT_DIR).filter(f => f.endsWith('.json'))
    if (files.length === 0) { console.log('No snapshots.'); return }
    for (const f of files) {
      const p = path.join(SNAPSHOT_DIR, f)
      const stat = fs.statSync(p)
      const sizeMB = (stat.size / 1024 / 1024).toFixed(1)
      console.log(`${f.replace(/\.json$/, '')}  ${sizeMB}MB  ${stat.mtime.toISOString()}`)
    }
    return
  }

  if (cmd === 'delete') {
    const label = args._[1]
    if (!label) { console.error('Usage: delete LABEL'); process.exit(1) }
    const p = path.join(SNAPSHOT_DIR, `${label}.json`)
    if (!fs.existsSync(p)) { console.error(`No snapshot: ${label}`); process.exit(1) }
    fs.unlinkSync(p)
    console.log(`Deleted: ${label}`)
    return
  }

  if (cmd === 'capture') {
    const label = args.flags.label
    if (!label || label === true) { console.error('--label NAME required'); process.exit(1) }

    let themes = DEFAULT_THEMES
    if (args.flags['all-themes']) themes = ALL_THEMES
    else if (args.flags.themes && args.flags.themes !== true) {
      const ids = String(args.flags.themes).split(',').map(s => parseInt(s.trim(), 10))
      themes = ALL_THEMES.filter(t => ids.includes(t.id))
      const missing = ids.filter(id => !ALL_THEMES.some(t => t.id === id))
      for (const id of missing) themes.push({ id, name: `theme-${id}` })
    }

    let viewports = ['mobile', 'desktop']
    if (args.flags.viewports && args.flags.viewports !== true) {
      viewports = String(args.flags.viewports).split(',').map(s => s.trim())
    }

    let pageList = args.flags.quick ? QUICK_PAGES : SWEEP_PAGES
    if (args.flags.pages && args.flags.pages !== true) {
      pageList = String(args.flags.pages).split(',').map(u => ({
        name: u.replace(/[^a-z0-9]/gi, '_').slice(0, 30),
        url: u,
      }))
    }

    const user = args.flags.user && args.flags.user !== true ? args.flags.user : null

    console.log(`Capturing snapshot "${label}"`)
    console.log(`  Themes: ${themes.length} (${themes.map(t => t.name).join(', ')})`)
    console.log(`  Viewports: ${viewports.join(', ')}`)
    console.log(`  Pages: ${pageList.length}`)
    console.log(`  User: ${user || '(guest, with lazy auth for auth-only pages)'}`)
    console.log('')

    await runCapture({ label, themes, viewports, pageList, user })
    return
  }

  if (cmd === 'compare') {
    const beforeLabel = args._[1]
    const afterLabel = args._[2]
    if (!beforeLabel || !afterLabel) { console.error('Usage: compare BEFORE AFTER'); process.exit(1) }

    const beforePath = path.join(SNAPSHOT_DIR, `${beforeLabel}.json`)
    const afterPath = path.join(SNAPSHOT_DIR, `${afterLabel}.json`)
    if (!fs.existsSync(beforePath)) { console.error(`Missing snapshot: ${beforeLabel}`); process.exit(1) }
    if (!fs.existsSync(afterPath)) { console.error(`Missing snapshot: ${afterLabel}`); process.exit(1) }

    const before = JSON.parse(fs.readFileSync(beforePath, 'utf8'))
    const after = JSON.parse(fs.readFileSync(afterPath, 'utf8'))

    const tolerancePx = args.flags.tolerance && args.flags.tolerance !== true ? parseFloat(args.flags.tolerance) : 1
    const maxIssues = args.flags['max-issues'] && args.flags['max-issues'] !== true ? parseInt(args.flags['max-issues'], 10) : 50

    const results = diffSnapshots(before, after, { tolerancePx, maxIssues })

    if (args.flags.json) {
      console.log(JSON.stringify(results, null, 2))
    } else {
      console.log(`\nDiffing  ${COLORS.dim}${beforeLabel}${COLORS.reset} → ${COLORS.bold}${afterLabel}${COLORS.reset}`)
      console.log(`Tolerance: ${tolerancePx}px,  max issues per cell: ${maxIssues}`)
      printDiffReport(results)
    }
    return
  }

  console.error(`Unknown command: ${cmd}. Try --help.`)
  process.exit(1)
}

main().catch(err => { console.error(err.stack || err.message); process.exit(1) })
