#!/usr/bin/env node

/**
 * Mobile Layout Checker - Computed Style Analysis
 *
 * Renders pages at mobile viewport width using Puppeteer and inspects
 * computed styles to detect layout issues programmatically. No screenshot
 * comparison needed - this checks the actual rendered layout math.
 *
 * Detects:
 *   - Elements overflowing the viewport (horizontal scroll)
 *   - Content clipped or pushed offscreen by margins/padding
 *   - Touch targets too small for mobile interaction
 *   - Text too small to read on mobile
 *   - Fixed pixel widths wider than viewport
 *   - Tables/pre blocks causing horizontal overflow
 *   - Hidden overflow masking child overflow issues
 *
 * Usage:
 *   node tools/mobile-layout-checker.js [url]                    # Check single page
 *   node tools/mobile-layout-checker.js [url] --theme 1965235    # Check with specific theme
 *   node tools/mobile-layout-checker.js --sweep                  # Check all representative pages
 *   node tools/mobile-layout-checker.js --sweep --all-themes     # Check all pages x all themes
 *   node tools/mobile-layout-checker.js --sweep --quick           # Quick subset
 *   node tools/mobile-layout-checker.js [url] --json             # JSON output
 *   node tools/mobile-layout-checker.js [url] --user e2e_user    # Authenticated check
 *   node tools/mobile-layout-checker.js [url] --verbose          # Show passing checks too
 */

const puppeteer = require('puppeteer')
const path = require('path')

const BASE_URL = process.env.E2_URL || 'http://development.everything2.com:9080'
const DEV_URL = 'http://development.everything2.com:9080'

const MOBILE_VIEWPORT = { width: 375, height: 812, deviceScaleFactor: 2, isMobile: true, hasTouch: true }
const MOBILE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15'

// Thresholds
const MIN_TOUCH_TARGET = 44    // Apple HIG minimum tap target (px)
const MIN_FONT_SIZE = 11       // Minimum readable font size (px)
const VIEWPORT_WIDTH = 375     // Mobile viewport width

// Test users
const TEST_USERS = {
  'root': { password: 'blah' },
  'e2e_admin': { password: 'test123' },
  'e2e_editor': { password: 'test123' },
  'e2e_user': { password: 'test123' },
  'genericdev': { password: 'blah' },
}

// All themes
const THEMES = [
  { id: 1965286, name: 'Bare Understatement' },
  { id: 1973976, name: 'basesheet' },
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

// Representative pages for sweep mode
const SWEEP_PAGES = [
  { name: 'front-page', url: '/', desc: 'Guest front page' },
  { name: 'e2node', url: '/title/tomato', desc: 'E2Node display' },
  { name: 'writeup', url: '/node/2212929', desc: 'Writeup display' },
  { name: 'user', url: '/user/root', desc: 'User homenode' },
  { name: 'search', url: '/title/Everything+User+Search', desc: 'User search' },
  { name: 'settings', url: '/title/Settings', desc: 'User settings', auth: true },
  { name: 'login', url: '/title/login', desc: 'Login page' },
  { name: 'signup', url: '/title/Sign+up', desc: 'Signup page' },
  { name: 'cool-archive', url: '/title/Cool+Archive', desc: 'Cool archive' },
  { name: 'document-directory', url: '/title/Everything+Document+Directory', desc: 'Document directory' },
  { name: 'news', url: '/title/News+for+noders.+Stuff+that+matters.', desc: 'News page' },
  { name: 'most-wanted', url: '/title/Everything%27s+Most+Wanted', desc: 'Most wanted' },
  { name: 'statistics', url: '/title/Everything+Statistics', desc: 'Statistics' },
  { name: 'message-inbox', url: '/title/Message+Inbox', desc: 'Message inbox', auth: true },
  { name: 'drafts', url: '/title/Drafts', desc: 'Drafts', auth: true },
  { name: 'achievements', url: '/title/My+Achievements', desc: 'Achievements', auth: true },
  { name: 'alphabetizer', url: '/title/alphabetizer', desc: 'Alphabetizer' },
  { name: 'category', url: '/title/Coffee+Culture', desc: 'Category display' },
  { name: 'poll-directory', url: '/title/Everything+Poll+Directory', desc: 'Poll directory' },
  { name: 'gift-shop', url: '/title/E2+Gift+Shop', desc: 'Gift shop' },
]

const QUICK_PAGES = SWEEP_PAGES.slice(0, 6)

function normalizeUrl(url) {
  return url.replace(/http:\/\/localhost:9080/g, DEV_URL)
}

// ─── Authentication ────────────────────────────────────────────────────────

async function loginUser(browser, username) {
  const user = TEST_USERS[username]
  if (!user) throw new Error(`Unknown test user: ${username}. Available: ${Object.keys(TEST_USERS).join(', ')}`)

  const page = await browser.newPage()
  // Login at desktop viewport (Sign In nodelet is in sidebar)
  await page.setViewport({ width: 1280, height: 1024 })
  await page.goto(DEV_URL, { waitUntil: 'networkidle0', timeout: 15000 })

  await page.waitForFunction(() => {
    const headers = Array.from(document.querySelectorAll('h2'))
    return headers.some(h => h.textContent.includes('Sign In'))
  }, { timeout: 5000 })

  // Expand Sign In nodelet if collapsed
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

  await page.waitForFunction(() => {
    return window.e2 && window.e2.user && !window.e2.user.guest
  }, { timeout: 15000 })

  const cookies = await page.cookies()
  await page.close()
  return cookies
}

// ─── Core Analysis ─────────────────────────────────────────────────────────

async function analyzePage(page, url, options = {}) {
  const fullUrl = url.startsWith('http') ? normalizeUrl(url) : `${DEV_URL}${url}`

  await page.goto(fullUrl, { waitUntil: 'networkidle0', timeout: 30000 })

  // Wait for React to finish rendering
  await page.waitForFunction(() => {
    const pageRoot = document.querySelector('#e2-react-page-root')
    return !pageRoot || !pageRoot.textContent.includes('Loading...')
  }, { timeout: 10000 }).catch(() => {})

  // Small settle time for any animations/transitions
  await new Promise(r => setTimeout(r, 500))

  const issues = await page.evaluate((thresholds) => {
    const { MIN_TOUCH_TARGET, MIN_FONT_SIZE, VIEWPORT_WIDTH } = thresholds
    const issues = []
    const seen = new Set()

    function getSelector(el) {
      if (el.id) return `#${el.id}`
      if (el.className && typeof el.className === 'string') {
        const cls = el.className.trim().split(/\s+/)[0]
        if (cls) return `${el.tagName.toLowerCase()}.${cls}`
      }
      // Build a path
      const parts = []
      let current = el
      while (current && current !== document.body && parts.length < 3) {
        let sel = current.tagName.toLowerCase()
        if (current.id) { sel = `#${current.id}`; parts.unshift(sel); break }
        if (current.className && typeof current.className === 'string') {
          const cls = current.className.trim().split(/\s+/)[0]
          if (cls) sel += `.${cls}`
        }
        parts.unshift(sel)
        current = current.parentElement
      }
      return parts.join(' > ')
    }

    function dedupe(category, selector) {
      const key = `${category}:${selector}`
      if (seen.has(key)) return true
      seen.add(key)
      return false
    }

    function isVisible(el) {
      const style = window.getComputedStyle(el)
      if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false
      const rect = el.getBoundingClientRect()
      if (rect.width === 0 && rect.height === 0) return false
      return true
    }

    function isInOverflowHiddenAncestor(el) {
      let current = el.parentElement
      while (current && current !== document.body) {
        const style = window.getComputedStyle(current)
        if (style.overflowX === 'hidden' || style.overflow === 'hidden') return true
        current = current.parentElement
      }
      return false
    }

    // Walk all visible elements
    const allElements = document.querySelectorAll('*')

    for (const el of allElements) {
      if (!isVisible(el)) continue

      const rect = el.getBoundingClientRect()
      const style = window.getComputedStyle(el)
      const selector = getSelector(el)
      const tag = el.tagName.toLowerCase()

      // Skip elements inside overflow:hidden containers for overflow checks
      // (they're visually clipped so the user won't see the overflow)
      const clippedByParent = isInOverflowHiddenAncestor(el)

      // ── 1. Horizontal overflow ──────────────────────────────────────
      if (!clippedByParent && rect.right > VIEWPORT_WIDTH + 2) {
        // Skip tiny overflows and body/html
        const overflow = Math.round(rect.right - VIEWPORT_WIDTH)
        if (overflow > 5 && tag !== 'html' && tag !== 'body') {
          if (!dedupe('overflow', selector)) {
            issues.push({
              type: 'horizontal-overflow',
              severity: overflow > 50 ? 'error' : 'warning',
              selector,
              tag,
              message: `Overflows viewport by ${overflow}px (right edge at ${Math.round(rect.right)}px)`,
              computed: {
                width: style.width,
                marginLeft: style.marginLeft,
                marginRight: style.marginRight,
                paddingLeft: style.paddingLeft,
                paddingRight: style.paddingRight,
                boxSizing: style.boxSizing,
              },
              rect: { left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width) },
            })
          }
        }
      }

      // ── 2. Content pushed offscreen left ────────────────────────────
      if (rect.right < 0 && rect.width > 0 && !clippedByParent) {
        if (!dedupe('offscreen-left', selector)) {
          issues.push({
            type: 'offscreen-left',
            severity: 'warning',
            selector,
            tag,
            message: `Element pushed entirely offscreen left (right edge at ${Math.round(rect.right)}px)`,
            computed: { marginLeft: style.marginLeft, left: style.left, position: style.position },
          })
        }
      }

      // ── 3. Touch target too small ───────────────────────────────────
      const isInteractive = tag === 'a' || tag === 'button' || tag === 'input' ||
        tag === 'select' || tag === 'textarea' || el.getAttribute('role') === 'button' ||
        el.getAttribute('tabindex') === '0' || style.cursor === 'pointer'

      if (isInteractive && rect.width > 0 && rect.height > 0) {
        const tooNarrow = rect.width < MIN_TOUCH_TARGET
        const tooShort = rect.height < MIN_TOUCH_TARGET
        if (tooNarrow || tooShort) {
          if (!dedupe('touch-target', selector)) {
            const textContent = (el.textContent || '').trim().substring(0, 30)
            issues.push({
              type: 'touch-target-too-small',
              severity: 'warning',
              selector,
              tag,
              message: `Touch target ${Math.round(rect.width)}x${Math.round(rect.height)}px (min ${MIN_TOUCH_TARGET}x${MIN_TOUCH_TARGET}px)`,
              text: textContent || undefined,
              rect: { width: Math.round(rect.width), height: Math.round(rect.height) },
            })
          }
        }
      }

      // ── 4. Text too small ───────────────────────────────────────────
      const hasText = el.childNodes.length > 0 &&
        Array.from(el.childNodes).some(n => n.nodeType === 3 && n.textContent.trim().length > 0)

      if (hasText) {
        const fontSize = parseFloat(style.fontSize)
        if (fontSize > 0 && fontSize < MIN_FONT_SIZE) {
          if (!dedupe('font-size', selector)) {
            issues.push({
              type: 'text-too-small',
              severity: 'info',
              selector,
              tag,
              message: `Font size ${fontSize}px is below ${MIN_FONT_SIZE}px minimum`,
              text: (el.textContent || '').trim().substring(0, 40),
              computed: { fontSize: style.fontSize, lineHeight: style.lineHeight },
            })
          }
        }
      }

      // ── 5. Fixed width wider than viewport ──────────────────────────
      const computedWidth = parseFloat(style.width)
      if (style.width.endsWith('px') && computedWidth > VIEWPORT_WIDTH && tag !== 'html' && tag !== 'body') {
        if (!clippedByParent && !dedupe('fixed-width', selector)) {
          issues.push({
            type: 'fixed-width-overflow',
            severity: 'warning',
            selector,
            tag,
            message: `Fixed width ${style.width} exceeds ${VIEWPORT_WIDTH}px viewport`,
            computed: { width: style.width, maxWidth: style.maxWidth, boxSizing: style.boxSizing },
          })
        }
      }

      // ── 6. Tables / pre blocks causing scroll ──────────────────────
      if ((tag === 'table' || tag === 'pre' || tag === 'code') && rect.width > VIEWPORT_WIDTH + 5) {
        if (!clippedByParent && !dedupe('wide-block', selector)) {
          // Check if parent has overflow-x: auto (acceptable)
          const parentStyle = el.parentElement ? window.getComputedStyle(el.parentElement) : null
          const parentScrollable = parentStyle &&
            (parentStyle.overflowX === 'auto' || parentStyle.overflowX === 'scroll')

          issues.push({
            type: 'wide-content-block',
            severity: parentScrollable ? 'info' : 'warning',
            selector,
            tag,
            message: `${tag} is ${Math.round(rect.width)}px wide (viewport: ${VIEWPORT_WIDTH}px)` +
              (parentScrollable ? ' [parent scrollable - OK]' : ' [no scroll wrapper]'),
            rect: { width: Math.round(rect.width) },
          })
        }
      }

      // ── 7. Margin math problems ─────────────────────────────────────
      // Check if margin + padding + content width exceeds parent
      if (el.parentElement && tag !== 'html' && tag !== 'body') {
        const parentRect = el.parentElement.getBoundingClientRect()
        const ml = parseFloat(style.marginLeft) || 0
        const mr = parseFloat(style.marginRight) || 0
        const totalWidth = ml + rect.width + mr

        if (totalWidth > parentRect.width + 5 && parentRect.width > 0 && !clippedByParent) {
          if (!dedupe('margin-overflow', selector)) {
            issues.push({
              type: 'margin-overflow',
              severity: 'warning',
              selector,
              tag,
              message: `Margin+width (${Math.round(ml)}+${Math.round(rect.width)}+${Math.round(mr)}=${Math.round(totalWidth)}px) exceeds parent (${Math.round(parentRect.width)}px)`,
              computed: {
                marginLeft: style.marginLeft,
                marginRight: style.marginRight,
                width: style.width,
                parentWidth: `${Math.round(parentRect.width)}px`,
              },
            })
          }
        }
      }
    }

    // ── 8. Document-level horizontal scroll check ────────────────────
    if (document.documentElement.scrollWidth > VIEWPORT_WIDTH + 5) {
      issues.unshift({
        type: 'page-horizontal-scroll',
        severity: 'error',
        selector: 'document',
        tag: 'html',
        message: `Page has horizontal scroll: scrollWidth ${document.documentElement.scrollWidth}px > viewport ${VIEWPORT_WIDTH}px`,
        computed: {
          scrollWidth: `${document.documentElement.scrollWidth}px`,
          clientWidth: `${document.documentElement.clientWidth}px`,
        },
      })
    }

    return issues
  }, { MIN_TOUCH_TARGET, MIN_FONT_SIZE, VIEWPORT_WIDTH })

  return {
    url: fullUrl.replace(DEV_URL, ''),
    issueCount: issues.length,
    errors: issues.filter(i => i.severity === 'error').length,
    warnings: issues.filter(i => i.severity === 'warning').length,
    info: issues.filter(i => i.severity === 'info').length,
    issues,
  }
}

// ─── Theme Switching ───────────────────────────────────────────────────────

async function setTheme(page, themeId) {
  // Set the theme cookie directly - E2 reads theme from userstyle cookie for guests
  await page.setCookie({
    name: 'userstyle',
    value: String(themeId),
    domain: 'development.everything2.com',
    path: '/',
  })
}

// ─── Output Formatting ────────────────────────────────────────────────────

const COLORS = {
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  cyan: '\x1b[36m',
  dim: '\x1b[2m',
  bold: '\x1b[1m',
  reset: '\x1b[0m',
}

function severityColor(severity) {
  if (severity === 'error') return COLORS.red
  if (severity === 'warning') return COLORS.yellow
  return COLORS.dim
}

function printPageResult(result, verbose = false) {
  const icon = result.errors > 0 ? `${COLORS.red}✗` :
    result.warnings > 0 ? `${COLORS.yellow}⚠` : `${COLORS.green}✓`

  console.log(`\n${icon} ${COLORS.bold}${result.url}${COLORS.reset}  ` +
    `${COLORS.red}${result.errors} errors${COLORS.reset}  ` +
    `${COLORS.yellow}${result.warnings} warnings${COLORS.reset}  ` +
    `${COLORS.dim}${result.info} info${COLORS.reset}`)

  if (result.issues.length === 0) {
    if (verbose) console.log(`  ${COLORS.green}No issues found${COLORS.reset}`)
    return
  }

  // Group by type
  const byType = {}
  for (const issue of result.issues) {
    if (!verbose && issue.severity === 'info') continue
    if (!byType[issue.type]) byType[issue.type] = []
    byType[issue.type].push(issue)
  }

  for (const [type, items] of Object.entries(byType)) {
    console.log(`\n  ${COLORS.cyan}[${type}]${COLORS.reset} (${items.length})`)
    for (const item of items.slice(0, 10)) {
      const color = severityColor(item.severity)
      console.log(`    ${color}${item.severity.toUpperCase()}${COLORS.reset} ${item.selector}`)
      console.log(`      ${item.message}`)
      if (item.text) console.log(`      ${COLORS.dim}text: "${item.text}"${COLORS.reset}`)
      if (item.computed && verbose) {
        const props = Object.entries(item.computed)
          .map(([k, v]) => `${k}: ${v}`)
          .join(', ')
        console.log(`      ${COLORS.dim}${props}${COLORS.reset}`)
      }
    }
    if (items.length > 10) {
      console.log(`    ${COLORS.dim}... and ${items.length - 10} more${COLORS.reset}`)
    }
  }
}

function printSummary(results) {
  console.log(`\n${'═'.repeat(70)}`)
  console.log(`${COLORS.bold}MOBILE LAYOUT CHECK SUMMARY${COLORS.reset}`)
  console.log(`${'═'.repeat(70)}`)

  let totalErrors = 0, totalWarnings = 0, totalInfo = 0, pagesClean = 0

  for (const r of results) {
    totalErrors += r.errors
    totalWarnings += r.warnings
    totalInfo += r.info
    if (r.errors === 0 && r.warnings === 0) pagesClean++
  }

  console.log(`\nPages checked: ${results.length}`)
  console.log(`Pages clean: ${COLORS.green}${pagesClean}${COLORS.reset} / ${results.length}`)
  console.log(`Total errors: ${totalErrors > 0 ? COLORS.red : COLORS.green}${totalErrors}${COLORS.reset}`)
  console.log(`Total warnings: ${totalWarnings > 0 ? COLORS.yellow : COLORS.green}${totalWarnings}${COLORS.reset}`)
  console.log(`Total info: ${totalInfo}`)

  // Top issue types
  const typeCount = {}
  for (const r of results) {
    for (const issue of r.issues) {
      typeCount[issue.type] = (typeCount[issue.type] || 0) + 1
    }
  }

  if (Object.keys(typeCount).length > 0) {
    console.log(`\n${COLORS.bold}Issue breakdown:${COLORS.reset}`)
    const sorted = Object.entries(typeCount).sort((a, b) => b[1] - a[1])
    for (const [type, count] of sorted) {
      console.log(`  ${type}: ${count}`)
    }
  }

  // Pages with most issues
  const worstPages = results.filter(r => r.issueCount > 0).sort((a, b) => b.issueCount - a.issueCount)
  if (worstPages.length > 0) {
    console.log(`\n${COLORS.bold}Pages with most issues:${COLORS.reset}`)
    for (const p of worstPages.slice(0, 10)) {
      console.log(`  ${p.url}: ${p.errors}E ${p.warnings}W ${p.info}I`)
    }
  }
}

// ─── Main ──────────────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2)

  if (args.includes('--help') || args.length === 0) {
    console.log(`
Mobile Layout Checker - Detect mobile CSS issues via computed styles

Usage:
  node tools/mobile-layout-checker.js [url]                     Check single page
  node tools/mobile-layout-checker.js [url] --theme 1965235     Check with specific theme
  node tools/mobile-layout-checker.js --sweep                   Check representative pages
  node tools/mobile-layout-checker.js --sweep --all-themes      Check all pages x all themes
  node tools/mobile-layout-checker.js --sweep --quick            Quick subset (6 pages)
  node tools/mobile-layout-checker.js [url] --user e2e_user     Check as authenticated user
  node tools/mobile-layout-checker.js [url] --json              JSON output
  node tools/mobile-layout-checker.js [url] --verbose           Show info-level + computed styles

What it checks:
  - horizontal-overflow:     Elements extending past viewport right edge
  - offscreen-left:          Elements pushed entirely off left edge
  - page-horizontal-scroll:  Document scrollWidth > viewport width
  - touch-target-too-small:  Interactive elements < 44x44px
  - text-too-small:          Text below 11px font size
  - fixed-width-overflow:    Pixel widths exceeding viewport
  - wide-content-block:      Tables/pre/code blocks wider than viewport
  - margin-overflow:         Margin + width exceeding parent container

Severity levels:
  ERROR    - Definitely broken (horizontal page scroll, large overflow)
  WARNING  - Likely a problem (small overflow, tiny touch targets)
  INFO     - Worth noting (scrollable tables, small text)
`)
    process.exit(0)
  }

  const sweep = args.includes('--sweep')
  const allThemes = args.includes('--all-themes')
  const quick = args.includes('--quick')
  const jsonOutput = args.includes('--json')
  const verbose = args.includes('--verbose')
  const themeIdx = args.indexOf('--theme')
  const themeId = themeIdx !== -1 ? args[themeIdx + 1] : null
  const userIdx = args.indexOf('--user')
  const username = userIdx !== -1 ? args[userIdx + 1] : null
  const url = args.find(a => a.startsWith('http') || a.startsWith('/'))

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
  })

  try {
    let authCookies = null
    if (username) {
      if (!jsonOutput) console.log(`Logging in as ${username}...`)
      authCookies = await loginUser(browser, username)
    }

    const allResults = []

    if (sweep) {
      // Sweep mode: check multiple pages
      const pages = quick ? QUICK_PAGES : SWEEP_PAGES
      const themes = allThemes ? THEMES : (themeId ? [{ id: parseInt(themeId), name: `theme-${themeId}` }] : [null])

      const totalChecks = pages.length * themes.length
      let completed = 0

      for (const theme of themes) {
        if (theme && !jsonOutput) {
          console.log(`\n${'─'.repeat(70)}`)
          console.log(`${COLORS.bold}Theme: ${theme.name} (${theme.id})${COLORS.reset}`)
          console.log(`${'─'.repeat(70)}`)
        }

        for (const pageInfo of pages) {
          completed++
          if (!jsonOutput) {
            process.stdout.write(`\r${COLORS.dim}[${completed}/${totalChecks}] Checking ${pageInfo.name}...${' '.repeat(30)}${COLORS.reset}`)
          }

          // Skip auth-required pages if no user provided
          if (pageInfo.auth && !authCookies) {
            // Auto-login as e2e_user for auth pages if no user specified
            if (!authCookies) {
              authCookies = await loginUser(browser, 'e2e_user')
            }
          }

          const page = await browser.newPage()
          await page.setViewport(MOBILE_VIEWPORT)
          await page.setUserAgent(MOBILE_UA)

          if (authCookies) await page.setCookie(...authCookies)
          if (theme) await setTheme(page, theme.id)

          try {
            const result = await analyzePage(page, pageInfo.url)
            if (theme) result.theme = theme.name
            allResults.push(result)

            if (!jsonOutput) {
              process.stdout.write('\r' + ' '.repeat(80) + '\r')
              printPageResult(result, verbose)
            }
          } catch (err) {
            if (!jsonOutput) {
              console.log(`\n  ${COLORS.red}ERROR loading ${pageInfo.url}: ${err.message}${COLORS.reset}`)
            }
            allResults.push({
              url: pageInfo.url,
              error: err.message,
              issueCount: 0, errors: 0, warnings: 0, info: 0,
              issues: [],
            })
          }

          await page.close()
        }
      }

      if (jsonOutput) {
        console.log(JSON.stringify(allResults, null, 2))
      } else {
        printSummary(allResults)
      }
    } else if (url) {
      // Single page mode
      const page = await browser.newPage()
      await page.setViewport(MOBILE_VIEWPORT)
      await page.setUserAgent(MOBILE_UA)

      if (authCookies) await page.setCookie(...authCookies)
      if (themeId) await setTheme(page, parseInt(themeId))

      const result = await analyzePage(page, url)

      if (jsonOutput) {
        console.log(JSON.stringify(result, null, 2))
      } else {
        printPageResult(result, verbose)
        console.log('')
      }

      await page.close()
    } else {
      console.error('Provide a URL or use --sweep mode. Run with --help for usage.')
      process.exit(1)
    }
  } catch (err) {
    console.error(`Fatal: ${err.message}`)
    process.exit(1)
  } finally {
    await browser.close()
  }
}

main()
