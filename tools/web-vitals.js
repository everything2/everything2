#!/usr/bin/env node
/**
 * Core Web Vitals Analysis Tool
 *
 * Uses the PageSpeed Insights API to analyze Core Web Vitals for E2 pages.
 * Provides both lab data (Lighthouse) and field data (CrUX) when available.
 *
 * Usage:
 *   node tools/web-vitals.js [url]                    # Analyze single URL (both mobile & desktop)
 *   node tools/web-vitals.js [url] --mobile           # Mobile only
 *   node tools/web-vitals.js [url] --desktop          # Desktop only
 *   node tools/web-vitals.js --top-pages              # Analyze top traffic pages
 *   node tools/web-vitals.js --compare                # Compare mobile vs desktop for key pages
 *
 * Examples:
 *   node tools/web-vitals.js https://everything2.com/
 *   node tools/web-vitals.js https://everything2.com/title/Polish+poker --desktop
 *   node tools/web-vitals.js --top-pages
 */

const { execSync } = require('child_process')

// PageSpeed Insights API endpoint
// Get a free API key from: https://developers.google.com/speed/docs/insights/v5/get-started
const PSI_API = 'https://pagespeedonline.googleapis.com/pagespeedonline/v5/runPagespeed'
const API_KEY = process.env.PAGESPEED_API_KEY || ''

// Top pages from Search Console data (high traffic)
const TOP_PAGES = [
  'https://everything2.com/',
  'https://everything2.com/title/My+Little+Pony+or+porn+star%3F',
  'https://everything2.com/title/Polish+poker',
  'https://everything2.com/title/Sex+with+a+chicken',
  'https://everything2.com/title/a+real-life+slave+contract',
  'https://everything2.com/title/The+Chuck+Norris+Cadence',
]

// Core Web Vitals thresholds (Google's official thresholds)
const THRESHOLDS = {
  LCP: { good: 2500, poor: 4000 },      // Largest Contentful Paint (ms)
  FID: { good: 100, poor: 300 },         // First Input Delay (ms)
  CLS: { good: 0.1, poor: 0.25 },        // Cumulative Layout Shift
  INP: { good: 200, poor: 500 },         // Interaction to Next Paint (ms)
  FCP: { good: 1800, poor: 3000 },       // First Contentful Paint (ms)
  TTFB: { good: 800, poor: 1800 },       // Time to First Byte (ms)
}

function fetchPSI(url, strategy = 'mobile') {
  return new Promise((resolve, reject) => {
    const params = new URLSearchParams({
      url: url,
      strategy: strategy,
      category: 'performance',
    })

    if (API_KEY) {
      params.append('key', API_KEY)
    }

    const fullUrl = `${PSI_API}?${params}`

    try {
      // Use curl for better SSL handling
      const result = execSync(`curl -s --max-time 60 "${fullUrl}"`, {
        encoding: 'utf8',
        maxBuffer: 10 * 1024 * 1024, // 10MB buffer for large responses
      })

      if (!result || result.trim() === '') {
        reject(new Error('Empty response from API'))
        return
      }

      resolve(JSON.parse(result))
    } catch (e) {
      if (e.message.includes('JSON')) {
        reject(new Error('Failed to parse API response'))
      } else {
        reject(new Error(`API request failed: ${e.message}`))
      }
    }
  })
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
    'good': '\x1b[32m',       // Green
    'needs-improvement': '\x1b[33m', // Yellow
    'poor': '\x1b[31m',       // Red
    'unknown': '\x1b[90m',    // Gray
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

function extractMetrics(data) {
  const metrics = {}

  // Field data (CrUX - real user data)
  const fieldData = data.loadingExperience?.metrics || {}

  if (fieldData.LARGEST_CONTENTFUL_PAINT_MS) {
    metrics.field = {
      LCP: fieldData.LARGEST_CONTENTFUL_PAINT_MS?.percentile,
      FID: fieldData.FIRST_INPUT_DELAY_MS?.percentile,
      CLS: fieldData.CUMULATIVE_LAYOUT_SHIFT_SCORE?.percentile / 100, // CrUX returns as percentage
      INP: fieldData.INTERACTION_TO_NEXT_PAINT?.percentile,
      FCP: fieldData.FIRST_CONTENTFUL_PAINT_MS?.percentile,
      TTFB: fieldData.EXPERIMENTAL_TIME_TO_FIRST_BYTE?.percentile,
    }
  }

  // Lab data (Lighthouse)
  const audits = data.lighthouseResult?.audits || {}
  metrics.lab = {
    LCP: audits['largest-contentful-paint']?.numericValue,
    FCP: audits['first-contentful-paint']?.numericValue,
    CLS: audits['cumulative-layout-shift']?.numericValue,
    TBT: audits['total-blocking-time']?.numericValue, // TBT approximates FID in lab
    SI: audits['speed-index']?.numericValue,
    TTI: audits['interactive']?.numericValue,
  }

  // Overall scores
  metrics.score = data.lighthouseResult?.categories?.performance?.score

  return metrics
}

function printResults(url, strategy, metrics) {
  console.log(`\n${'='.repeat(70)}`)
  console.log(`URL: ${url}`)
  console.log(`Strategy: ${strategy.toUpperCase()}`)
  console.log(`${'='.repeat(70)}`)

  // Performance score
  if (metrics.score !== undefined) {
    const scorePercent = Math.round(metrics.score * 100)
    let scoreRating = 'poor'
    if (scorePercent >= 90) scoreRating = 'good'
    else if (scorePercent >= 50) scoreRating = 'needs-improvement'
    console.log(`\nPerformance Score: ${colorize(scorePercent + '/100', scoreRating)}`)
  }

  // Field data (real users)
  if (metrics.field) {
    console.log(`\n${'─'.repeat(40)}`)
    console.log('FIELD DATA (Real Users - CrUX)')
    console.log(`${'─'.repeat(40)}`)
    console.log(`  ${formatMetric('LCP', metrics.field.LCP)} (75th percentile)`)
    console.log(`  ${formatMetric('FID', metrics.field.FID)} (75th percentile)`)
    console.log(`  ${formatMetric('INP', metrics.field.INP)} (75th percentile)`)
    console.log(`  ${formatMetric('CLS', metrics.field.CLS)} (75th percentile)`)
    console.log(`  ${formatMetric('FCP', metrics.field.FCP)} (75th percentile)`)
    console.log(`  ${formatMetric('TTFB', metrics.field.TTFB)} (75th percentile)`)
  } else {
    console.log(`\n${colorize('No field data available (not enough traffic in CrUX)', 'unknown')}`)
  }

  // Lab data (Lighthouse)
  console.log(`\n${'─'.repeat(40)}`)
  console.log('LAB DATA (Lighthouse Simulation)')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  ${formatMetric('LCP', metrics.lab.LCP)}`)
  console.log(`  ${formatMetric('FCP', metrics.lab.FCP)}`)
  console.log(`  ${formatMetric('CLS', metrics.lab.CLS)}`)
  console.log(`  TBT: ${Math.round(metrics.lab.TBT || 0)}ms (proxy for FID)`)
  console.log(`  Speed Index: ${Math.round(metrics.lab.SI || 0)}ms`)
  console.log(`  Time to Interactive: ${Math.round(metrics.lab.TTI || 0)}ms`)
}

function printComparisonTable(results) {
  console.log(`\n${'='.repeat(90)}`)
  console.log('MOBILE vs DESKTOP COMPARISON')
  console.log(`${'='.repeat(90)}`)

  // Header
  console.log('\n' + 'URL'.padEnd(45) + 'Mobile Score'.padEnd(15) + 'Desktop Score'.padEnd(15) + 'Gap')
  console.log('─'.repeat(90))

  for (const result of results) {
    const mobileScore = result.mobile?.score !== undefined ? Math.round(result.mobile.score * 100) : 'N/A'
    const desktopScore = result.desktop?.score !== undefined ? Math.round(result.desktop.score * 100) : 'N/A'

    let gap = ''
    if (typeof mobileScore === 'number' && typeof desktopScore === 'number') {
      const diff = desktopScore - mobileScore
      gap = diff > 0 ? colorize(`+${diff}`, 'good') : colorize(`${diff}`, diff < -10 ? 'poor' : 'needs-improvement')
    }

    // Truncate URL for display
    let displayUrl = result.url.replace('https://everything2.com', '')
    if (displayUrl.length > 43) displayUrl = displayUrl.substring(0, 40) + '...'

    const mobileStr = typeof mobileScore === 'number'
      ? colorize(mobileScore.toString(), mobileScore >= 90 ? 'good' : mobileScore >= 50 ? 'needs-improvement' : 'poor')
      : mobileScore
    const desktopStr = typeof desktopScore === 'number'
      ? colorize(desktopScore.toString(), desktopScore >= 90 ? 'good' : desktopScore >= 50 ? 'needs-improvement' : 'poor')
      : desktopScore

    console.log(`${displayUrl.padEnd(45)}${mobileStr.padEnd(25)}${desktopStr.padEnd(25)}${gap}`)
  }

  // LCP comparison
  console.log('\n' + 'URL'.padEnd(45) + 'Mobile LCP'.padEnd(15) + 'Desktop LCP'.padEnd(15) + 'Notes')
  console.log('─'.repeat(90))

  for (const result of results) {
    const mobileLCP = result.mobile?.lab?.LCP
    const desktopLCP = result.desktop?.lab?.LCP

    let displayUrl = result.url.replace('https://everything2.com', '')
    if (displayUrl.length > 43) displayUrl = displayUrl.substring(0, 40) + '...'

    const mobileStr = mobileLCP ? formatMetric('', mobileLCP).replace(': ', '') : 'N/A'
    const desktopStr = desktopLCP ? formatMetric('', desktopLCP).replace(': ', '') : 'N/A'

    let notes = ''
    if (mobileLCP && desktopLCP) {
      if (desktopLCP > mobileLCP * 1.5) notes = colorize('Desktop much slower', 'poor')
      else if (desktopLCP < mobileLCP * 0.7) notes = colorize('Desktop faster', 'good')
    }

    console.log(`${displayUrl.padEnd(45)}${mobileStr.padEnd(25)}${desktopStr.padEnd(25)}${notes}`)
  }
}

async function analyzeSingleUrl(url, strategies) {
  for (const strategy of strategies) {
    console.log(`\nAnalyzing ${strategy}... (this may take 20-30 seconds)`)
    try {
      const data = await fetchPSI(url, strategy)

      if (data.error) {
        console.error(`Error: ${data.error.message}`)
        continue
      }

      const metrics = extractMetrics(data)
      printResults(url, strategy, metrics)
    } catch (err) {
      console.error(`Failed to analyze ${strategy}: ${err.message}`)
    }
  }
}

async function analyzeTopPages() {
  console.log('Analyzing top traffic pages...')
  console.log('This will take several minutes due to API rate limits.\n')

  const results = []

  for (const url of TOP_PAGES) {
    console.log(`\nAnalyzing: ${url}`)
    const result = { url }

    for (const strategy of ['mobile', 'desktop']) {
      process.stdout.write(`  ${strategy}...`)
      try {
        const data = await fetchPSI(url, strategy)
        if (!data.error) {
          result[strategy] = extractMetrics(data)
          process.stdout.write(` done\n`)
        } else {
          process.stdout.write(` error: ${data.error.message}\n`)
        }
      } catch (err) {
        process.stdout.write(` failed: ${err.message}\n`)
      }

      // Rate limit: wait 2 seconds between requests
      await new Promise(resolve => setTimeout(resolve, 2000))
    }

    results.push(result)
  }

  printComparisonTable(results)
}

async function main() {
  const args = process.argv.slice(2)

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
Core Web Vitals Analysis Tool

Usage:
  node tools/web-vitals.js [url]                    Analyze URL (mobile & desktop)
  node tools/web-vitals.js [url] --mobile           Mobile only
  node tools/web-vitals.js [url] --desktop          Desktop only
  node tools/web-vitals.js --top-pages              Analyze top E2 pages
  node tools/web-vitals.js --compare                Compare mobile vs desktop

Environment:
  PAGESPEED_API_KEY    API key for PageSpeed Insights (recommended)
                       Get one free at: https://developers.google.com/speed/docs/insights/v5/get-started

Metrics explained:
  LCP  - Largest Contentful Paint: When main content loads (< 2.5s good)
  FID  - First Input Delay: Response to first interaction (< 100ms good)
  INP  - Interaction to Next Paint: Overall responsiveness (< 200ms good)
  CLS  - Cumulative Layout Shift: Visual stability (< 0.1 good)
  FCP  - First Contentful Paint: When first content appears (< 1.8s good)
  TTFB - Time to First Byte: Server response time (< 800ms good)
`)
    process.exit(0)
  }

  if (!API_KEY) {
    console.log('Warning: No PAGESPEED_API_KEY set. API may be rate-limited.')
    console.log('Get a free key at: https://developers.google.com/speed/docs/insights/v5/get-started')
    console.log('')
  }

  if (args.includes('--top-pages') || args.includes('--compare')) {
    await analyzeTopPages()
    return
  }

  // Single URL analysis
  const url = args.find(arg => arg.startsWith('http'))
  if (!url) {
    console.error('Please provide a URL to analyze')
    process.exit(1)
  }

  let strategies = ['mobile', 'desktop']
  if (args.includes('--mobile')) strategies = ['mobile']
  if (args.includes('--desktop')) strategies = ['desktop']

  await analyzeSingleUrl(url, strategies)
}

main().catch(err => {
  console.error('Fatal error:', err.message)
  process.exit(1)
})
