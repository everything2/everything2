#!/usr/bin/env node

/**
 * CSS Coverage Analysis Tool
 *
 * Uses Puppeteer to analyze which CSS rules are actually used across pages.
 * This helps identify dead CSS and verify that refactoring hasn't broken styling.
 *
 * Usage:
 *   node tools/css-coverage.js [--pages N] [--output coverage-report.json]
 */

const puppeteer = require('puppeteer')
const fs = require('fs')
const path = require('path')

const BASE_URL = process.env.E2_BASE_URL || 'http://localhost:9080'

// Representative pages to test coverage
const TEST_PAGES = [
  '/',
  '/title/tomato',
  '/title/Settings',
  '/title/Everything%20User%20Search',
  '/title/News%20for%20noders.%20Stuff%20that%20matters.',
  '/title/Everything%27s%20Most%20Wanted',
  '/title/Chatterlight',
  '/title/My%20Achievements',
  '/title/Everything%20Document%20Directory',
  '/title/E2%20Gift%20Shop',
  '/user/root',
  '/node/2212929', // A writeup
]

async function login(page, username, password) {
  // Use API-based login (the form uses React and submits via API)
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2' })

  // Login via API
  const loginResult = await page.evaluate(async (user, pass) => {
    const response = await fetch('/api/sessions/create', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ username: user, passwd: pass, expires: '+1y' })
    })
    return response.ok
  }, username, password)

  if (!loginResult) {
    throw new Error('Login failed')
  }

  // Reload to apply session
  await page.goto(`${BASE_URL}/`, { waitUntil: 'networkidle2' })
}

async function getCSSCoverage(page, url) {
  // Start CSS coverage
  await page.coverage.startCSSCoverage()

  // Navigate to page
  await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 })

  // Wait a bit for any dynamic content
  await page.evaluate(() => new Promise(r => setTimeout(r, 1000)))

  // Get coverage data
  const coverage = await page.coverage.stopCSSCoverage()

  return coverage
}

function analyzeCoverage(allCoverage) {
  const ruleUsage = new Map()
  const fileStats = new Map()

  for (const entry of allCoverage) {
    const url = entry.url
    const text = entry.text
    const ranges = entry.ranges

    // Calculate used vs total bytes
    let usedBytes = 0
    for (const range of ranges) {
      usedBytes += range.end - range.start
    }
    const totalBytes = text.length
    const usedPercent = totalBytes > 0 ? (usedBytes / totalBytes * 100).toFixed(1) : 0

    // Track per-file stats
    const filename = url.split('/').pop()
    if (!fileStats.has(filename)) {
      fileStats.set(filename, { totalBytes: 0, usedBytes: 0, pages: 0 })
    }
    const stats = fileStats.get(filename)
    stats.totalBytes = Math.max(stats.totalBytes, totalBytes)
    stats.usedBytes = Math.max(stats.usedBytes, usedBytes)
    stats.pages++
  }

  return { fileStats }
}

async function main() {
  const args = process.argv.slice(2)
  const outputFile = args.includes('--output')
    ? args[args.indexOf('--output') + 1]
    : 'coverage-report.json'

  console.log('CSS Coverage Analysis Tool')
  console.log('==========================\n')

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  })

  const page = await browser.newPage()
  await page.setViewport({ width: 1920, height: 1080 })

  // Login as admin to access all pages
  console.log('Logging in as e2e_admin...')
  await login(page, 'e2e_admin', 'test123')

  const allCoverage = []

  for (const pagePath of TEST_PAGES) {
    const url = `${BASE_URL}${pagePath}`
    console.log(`Analyzing: ${pagePath}`)

    try {
      const coverage = await getCSSCoverage(page, url)
      allCoverage.push(...coverage)
    } catch (err) {
      console.error(`  Error: ${err.message}`)
    }
  }

  await browser.close()

  // Analyze results
  const { fileStats } = analyzeCoverage(allCoverage)

  console.log('\n\nCSS Coverage Summary')
  console.log('====================\n')

  const sortedFiles = [...fileStats.entries()].sort((a, b) => {
    const aPercent = a[1].usedBytes / a[1].totalBytes
    const bPercent = b[1].usedBytes / b[1].totalBytes
    return aPercent - bPercent
  })

  for (const [filename, stats] of sortedFiles) {
    const usedPercent = (stats.usedBytes / stats.totalBytes * 100).toFixed(1)
    const unusedKB = ((stats.totalBytes - stats.usedBytes) / 1024).toFixed(1)
    console.log(`${filename}:`)
    console.log(`  Used: ${usedPercent}% (${unusedKB}KB unused)`)
    console.log(`  Total: ${(stats.totalBytes / 1024).toFixed(1)}KB`)
    console.log('')
  }

  // Save detailed report
  const report = {
    timestamp: new Date().toISOString(),
    baseUrl: BASE_URL,
    pagesAnalyzed: TEST_PAGES.length,
    files: Object.fromEntries(sortedFiles)
  }

  fs.writeFileSync(outputFile, JSON.stringify(report, null, 2))
  console.log(`\nDetailed report saved to: ${outputFile}`)
}

main().catch(err => {
  console.error('Error:', err)
  process.exit(1)
})
