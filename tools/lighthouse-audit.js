#!/usr/bin/env node
/**
 * Lighthouse Performance Audit Tool
 *
 * Runs Lighthouse audits locally using Chrome/Puppeteer.
 * No API key required - runs directly on your machine.
 *
 * Usage:
 *   node tools/lighthouse-audit.js [url]                # Audit single URL
 *   node tools/lighthouse-audit.js [url] --mobile       # Mobile only (default)
 *   node tools/lighthouse-audit.js [url] --desktop      # Desktop only
 *   node tools/lighthouse-audit.js [url] --json         # Output raw JSON
 *   node tools/lighthouse-audit.js --top-pages          # Audit top traffic pages
 *
 * Requires: npm install lighthouse puppeteer (if not already installed)
 */

const { execSync, spawn } = require('child_process')
const path = require('path')
const fs = require('fs')

// Top pages from Search Console data
const TOP_PAGES = [
  'https://everything2.com/',
  'https://everything2.com/title/My+Little+Pony+or+porn+star%3F',
  'https://everything2.com/title/Polish+poker',
  'https://everything2.com/title/The+Chuck+Norris+Cadence',
]

// Core Web Vitals thresholds
const THRESHOLDS = {
  LCP: { good: 2500, poor: 4000 },
  CLS: { good: 0.1, poor: 0.25 },
  TBT: { good: 200, poor: 600 },
  FCP: { good: 1800, poor: 3000 },
  SI: { good: 3400, poor: 5800 },
  TTI: { good: 3800, poor: 7300 },
}

function getRating(value, metric) {
  const threshold = THRESHOLDS[metric]
  if (!threshold) return 'unknown'
  if (value <= threshold.good) return 'good'
  if (value <= threshold.poor) return 'needs-improvement'
  return 'poor'
}

function colorize(text, rating) {
  const colors = {
    'good': '\x1b[32m',
    'needs-improvement': '\x1b[33m',
    'poor': '\x1b[31m',
    'unknown': '\x1b[90m',
  }
  const reset = '\x1b[0m'
  return `${colors[rating] || ''}${text}${reset}`
}

function formatMetric(name, value, unit = 'ms') {
  if (value === null || value === undefined) {
    return colorize(`${name}: N/A`, 'unknown')
  }

  const rating = getRating(value, name)
  const displayValue = name === 'CLS' ? value.toFixed(3) : Math.round(value)
  const displayUnit = name === 'CLS' ? '' : unit

  return colorize(`${name}: ${displayValue}${displayUnit}`, rating)
}

async function runLighthouse(url, formFactor = 'mobile') {
  // Check if lighthouse is installed
  try {
    execSync('npx lighthouse --version', { stdio: 'pipe' })
  } catch (e) {
    console.error('Lighthouse not found. Installing...')
    execSync('npm install lighthouse', { stdio: 'inherit' })
  }

  const outputPath = `/tmp/lighthouse-${Date.now()}.json`

  // Find Chrome/Chromium
  let chromePath = ''
  try {
    chromePath = execSync('which chromium-browser chromium google-chrome 2>/dev/null | head -1', { encoding: 'utf8' }).trim()
  } catch (e) {
    // Ignore - will use default
  }

  const args = [
    'lighthouse',
    url,
    '--output=json',
    `--output-path=${outputPath}`,
    '--only-categories=performance',
    '--chrome-flags="--headless --no-sandbox --disable-gpu --disable-dev-shm-usage"',
    `--form-factor=${formFactor}`,
    '--quiet',
  ]

  if (chromePath) {
    args.push(`--chrome-path=${chromePath}`)
  }

  if (formFactor === 'desktop') {
    args.push('--preset=desktop')
  }

  console.log(`Running Lighthouse (${formFactor})...`)

  try {
    execSync(`npx ${args.join(' ')}`, {
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 120000,
    })

    const report = JSON.parse(fs.readFileSync(outputPath, 'utf8'))
    fs.unlinkSync(outputPath)
    return report
  } catch (e) {
    // Try to read partial results
    if (fs.existsSync(outputPath)) {
      try {
        const report = JSON.parse(fs.readFileSync(outputPath, 'utf8'))
        fs.unlinkSync(outputPath)
        return report
      } catch (parseErr) {
        fs.unlinkSync(outputPath)
      }
    }
    throw new Error(`Lighthouse failed: ${e.message}`)
  }
}

function extractMetrics(report) {
  const audits = report.audits || {}

  return {
    score: report.categories?.performance?.score,
    LCP: audits['largest-contentful-paint']?.numericValue,
    FCP: audits['first-contentful-paint']?.numericValue,
    CLS: audits['cumulative-layout-shift']?.numericValue,
    TBT: audits['total-blocking-time']?.numericValue,
    SI: audits['speed-index']?.numericValue,
    TTI: audits['interactive']?.numericValue,
    // Additional useful metrics
    serverResponseTime: audits['server-response-time']?.numericValue,
    renderBlocking: audits['render-blocking-resources']?.details?.items?.length || 0,
    unusedJS: audits['unused-javascript']?.details?.overallSavingsMs,
    unusedCSS: audits['unused-css-rules']?.details?.overallSavingsMs,
    mainThreadWork: audits['mainthread-work-breakdown']?.numericValue,
    domSize: audits['dom-size']?.numericValue,
  }
}

function printResults(url, formFactor, metrics) {
  console.log(`\n${'='.repeat(70)}`)
  console.log(`URL: ${url}`)
  console.log(`Form Factor: ${formFactor.toUpperCase()}`)
  console.log(`${'='.repeat(70)}`)

  // Performance score
  if (metrics.score !== undefined) {
    const scorePercent = Math.round(metrics.score * 100)
    let scoreRating = 'poor'
    if (scorePercent >= 90) scoreRating = 'good'
    else if (scorePercent >= 50) scoreRating = 'needs-improvement'
    console.log(`\nPerformance Score: ${colorize(scorePercent + '/100', scoreRating)}`)
  }

  // Core Web Vitals
  console.log(`\n${'─'.repeat(40)}`)
  console.log('CORE WEB VITALS')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  ${formatMetric('LCP', metrics.LCP)} (< 2.5s good)`)
  console.log(`  ${formatMetric('CLS', metrics.CLS)} (< 0.1 good)`)
  console.log(`  ${formatMetric('TBT', metrics.TBT)} (< 200ms good, proxy for INP)`)

  // Other performance metrics
  console.log(`\n${'─'.repeat(40)}`)
  console.log('OTHER METRICS')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  ${formatMetric('FCP', metrics.FCP)} (< 1.8s good)`)
  console.log(`  ${formatMetric('SI', metrics.SI)} (< 3.4s good)`)
  console.log(`  ${formatMetric('TTI', metrics.TTI)} (< 3.8s good)`)

  // Diagnostics
  console.log(`\n${'─'.repeat(40)}`)
  console.log('DIAGNOSTICS')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  Server Response Time: ${Math.round(metrics.serverResponseTime || 0)}ms`)
  console.log(`  Render-blocking resources: ${metrics.renderBlocking}`)
  console.log(`  Unused JS savings: ${Math.round(metrics.unusedJS || 0)}ms`)
  console.log(`  Unused CSS savings: ${Math.round(metrics.unusedCSS || 0)}ms`)
  console.log(`  Main thread work: ${Math.round(metrics.mainThreadWork || 0)}ms`)
  console.log(`  DOM size: ${metrics.domSize || 'N/A'} elements`)
}

async function main() {
  const args = process.argv.slice(2)

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
Lighthouse Performance Audit Tool

Usage:
  node tools/lighthouse-audit.js [url]                Audit URL (mobile by default)
  node tools/lighthouse-audit.js [url] --desktop      Desktop audit
  node tools/lighthouse-audit.js [url] --both         Both mobile and desktop
  node tools/lighthouse-audit.js --top-pages          Audit top E2 pages

This runs Lighthouse locally - no API key needed.
Results are lab-only (no real user data like CrUX).

Metrics:
  LCP  - Largest Contentful Paint: When main content loads
  CLS  - Cumulative Layout Shift: Visual stability
  TBT  - Total Blocking Time: Proxy for interactivity (like FID/INP)
  FCP  - First Contentful Paint: When first content appears
  SI   - Speed Index: How quickly content is visually displayed
  TTI  - Time to Interactive: When page is fully interactive
`)
    process.exit(0)
  }

  if (args.includes('--top-pages')) {
    console.log('Auditing top traffic pages...\n')

    for (const url of TOP_PAGES) {
      try {
        const report = await runLighthouse(url, 'mobile')
        const metrics = extractMetrics(report)
        printResults(url, 'mobile', metrics)
      } catch (err) {
        console.error(`Failed to audit ${url}: ${err.message}`)
      }
      console.log('')
    }
    return
  }

  const url = args.find(arg => arg.startsWith('http'))
  if (!url) {
    console.error('Please provide a URL to audit')
    process.exit(1)
  }

  const formFactors = []
  if (args.includes('--both')) {
    formFactors.push('mobile', 'desktop')
  } else if (args.includes('--desktop')) {
    formFactors.push('desktop')
  } else {
    formFactors.push('mobile')
  }

  for (const formFactor of formFactors) {
    try {
      const report = await runLighthouse(url, formFactor)

      if (args.includes('--json')) {
        console.log(JSON.stringify(report, null, 2))
      } else {
        const metrics = extractMetrics(report)
        printResults(url, formFactor, metrics)
      }
    } catch (err) {
      console.error(`Failed to audit (${formFactor}): ${err.message}`)
    }
  }
}

main().catch(err => {
  console.error('Fatal error:', err.message)
  process.exit(1)
})
