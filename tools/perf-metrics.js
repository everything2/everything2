#!/usr/bin/env node
/**
 * Performance Metrics Tool
 *
 * Uses Puppeteer to extract Core Web Vitals and performance metrics directly.
 * Works without API keys using the browser's Performance API.
 *
 * Usage:
 *   node tools/perf-metrics.js [url]                 # Analyze URL (mobile viewport)
 *   node tools/perf-metrics.js [url] --desktop       # Desktop viewport
 *   node tools/perf-metrics.js [url] --both          # Both mobile and desktop
 *   node tools/perf-metrics.js --top-pages           # Analyze top E2 pages
 *
 * Requires: puppeteer (already installed for browser-debug.js)
 */

const puppeteer = require('puppeteer')

// Top pages from Search Console data
const TOP_PAGES = [
  'https://everything2.com/',
  'https://everything2.com/title/My+Little+Pony+or+porn+star%3F',
  'https://everything2.com/title/Polish+poker',
  'https://everything2.com/title/The+Chuck+Norris+Cadence',
  'https://everything2.com/title/Behind+the+Green+Door',
]

// Core Web Vitals thresholds
const THRESHOLDS = {
  LCP: { good: 2500, poor: 4000 },
  CLS: { good: 0.1, poor: 0.25 },
  FCP: { good: 1800, poor: 3000 },
  TTFB: { good: 800, poor: 1800 },
  TBT: { good: 200, poor: 600 },
  DCL: { good: 2500, poor: 4000 },
  Load: { good: 3000, poor: 6000 },
}

const VIEWPORTS = {
  mobile: { width: 375, height: 667, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desktop: { width: 1920, height: 1080, deviceScaleFactor: 1, isMobile: false, hasTouch: false },
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
  if (value === null || value === undefined || isNaN(value)) {
    return colorize(`${name}: N/A`, 'unknown')
  }

  const rating = getRating(value, name)
  const displayValue = name === 'CLS' ? value.toFixed(3) : Math.round(value)
  const displayUnit = name === 'CLS' ? '' : unit

  return colorize(`${name}: ${displayValue}${displayUnit}`, rating)
}

async function measurePerformance(url, viewport = 'mobile') {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
    ],
  })

  try {
    const page = await browser.newPage()

    // Set viewport
    await page.setViewport(VIEWPORTS[viewport])

    // Set mobile user agent for mobile viewport
    if (viewport === 'mobile') {
      await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1')
    }

    // Enable performance metrics collection
    await page.setCacheEnabled(false)

    // Inject web-vitals library for accurate CLS measurement
    const webVitalsScript = `
      window.__webVitals = { cls: 0, clsEntries: [] };

      // Observe layout shifts
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) {
            window.__webVitals.cls += entry.value;
            window.__webVitals.clsEntries.push({
              value: entry.value,
              sources: entry.sources?.map(s => s.node?.nodeName) || []
            });
          }
        }
      });
      observer.observe({ type: 'layout-shift', buffered: true });

      // Observe LCP
      window.__webVitals.lcp = 0;
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const lastEntry = entries[entries.length - 1];
        window.__webVitals.lcp = lastEntry.startTime;
        window.__webVitals.lcpElement = lastEntry.element?.tagName;
      });
      lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true });
    `

    // Start measuring
    const startTime = Date.now()

    // Navigate with performance timing
    const response = await page.goto(url, {
      waitUntil: 'networkidle2',
      timeout: 60000,
    })

    // Inject web vitals observer after navigation
    await page.evaluate(webVitalsScript)

    // Wait a bit more for any late layout shifts
    await new Promise(resolve => setTimeout(resolve, 2000))

    // Collect metrics
    const metrics = await page.evaluate(() => {
      const perf = performance
      const timing = perf.timing || {}
      const entries = perf.getEntriesByType('navigation')[0] || {}

      // Get paint timings
      const paintEntries = perf.getEntriesByType('paint')
      const fcp = paintEntries.find(e => e.name === 'first-contentful-paint')?.startTime
      const fp = paintEntries.find(e => e.name === 'first-paint')?.startTime

      // Get LCP from PerformanceObserver
      const lcp = window.__webVitals?.lcp || 0
      const lcpElement = window.__webVitals?.lcpElement || 'unknown'

      // Get CLS
      const cls = window.__webVitals?.cls || 0

      // Resource timing
      const resources = perf.getEntriesByType('resource')
      const jsResources = resources.filter(r => r.initiatorType === 'script')
      const cssResources = resources.filter(r => r.initiatorType === 'link' || r.name.endsWith('.css'))
      const imageResources = resources.filter(r => r.initiatorType === 'img')

      // Calculate blocking time (simplified)
      const longTasks = perf.getEntriesByType('longtask') || []
      const tbt = longTasks.reduce((total, task) => {
        const blockingTime = task.duration - 50 // Tasks over 50ms
        return total + (blockingTime > 0 ? blockingTime : 0)
      }, 0)

      return {
        // Navigation timing
        ttfb: entries.responseStart || (timing.responseStart - timing.navigationStart),
        domContentLoaded: entries.domContentLoadedEventEnd || (timing.domContentLoadedEventEnd - timing.navigationStart),
        load: entries.loadEventEnd || (timing.loadEventEnd - timing.navigationStart),

        // Paint timing
        fp,
        fcp,
        lcp,
        lcpElement,

        // Layout stability
        cls,
        clsEntries: window.__webVitals?.clsEntries || [],

        // Blocking time
        tbt,

        // Resource counts
        totalResources: resources.length,
        jsCount: jsResources.length,
        cssCount: cssResources.length,
        imageCount: imageResources.length,

        // Resource sizes
        totalTransferred: resources.reduce((sum, r) => sum + (r.transferSize || 0), 0),
        jsTransferred: jsResources.reduce((sum, r) => sum + (r.transferSize || 0), 0),
        cssTransferred: cssResources.reduce((sum, r) => sum + (r.transferSize || 0), 0),

        // DOM info
        domElements: document.querySelectorAll('*').length,
      }
    })

    // Get response info
    const responseHeaders = response.headers()
    metrics.httpStatus = response.status()
    metrics.serverTiming = responseHeaders['server-timing'] || ''
    metrics.cacheStatus = responseHeaders['x-cache'] || responseHeaders['cf-cache-status'] || ''

    return metrics
  } finally {
    await browser.close()
  }
}

function printResults(url, viewport, metrics) {
  console.log(`\n${'='.repeat(70)}`)
  console.log(`URL: ${url}`)
  console.log(`Viewport: ${viewport.toUpperCase()} (${VIEWPORTS[viewport].width}x${VIEWPORTS[viewport].height})`)
  console.log(`${'='.repeat(70)}`)

  // Core Web Vitals
  console.log(`\n${'─'.repeat(40)}`)
  console.log('CORE WEB VITALS')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  ${formatMetric('LCP', metrics.lcp)} (${metrics.lcpElement})`)
  console.log(`  ${formatMetric('CLS', metrics.cls)}`)
  console.log(`  ${formatMetric('TBT', metrics.tbt)} (proxy for INP/FID)`)

  // Loading metrics
  console.log(`\n${'─'.repeat(40)}`)
  console.log('LOADING METRICS')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  ${formatMetric('TTFB', metrics.ttfb)}`)
  console.log(`  ${formatMetric('FCP', metrics.fcp)}`)
  console.log(`  ${formatMetric('DCL', metrics.domContentLoaded)} (DOMContentLoaded)`)
  console.log(`  ${formatMetric('Load', metrics.load)} (Load event)`)

  // Resource info
  console.log(`\n${'─'.repeat(40)}`)
  console.log('RESOURCES')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  Total requests: ${metrics.totalResources}`)
  console.log(`  JS files: ${metrics.jsCount} (${formatBytes(metrics.jsTransferred)})`)
  console.log(`  CSS files: ${metrics.cssCount} (${formatBytes(metrics.cssTransferred)})`)
  console.log(`  Images: ${metrics.imageCount}`)
  console.log(`  Total transferred: ${formatBytes(metrics.totalTransferred)}`)
  console.log(`  DOM elements: ${metrics.domElements}`)

  // Server info
  console.log(`\n${'─'.repeat(40)}`)
  console.log('SERVER')
  console.log(`${'─'.repeat(40)}`)
  console.log(`  HTTP Status: ${metrics.httpStatus}`)
  console.log(`  Cache: ${metrics.cacheStatus || 'N/A'}`)

  // CLS breakdown if significant
  if (metrics.cls > 0.05 && metrics.clsEntries?.length > 0) {
    console.log(`\n${'─'.repeat(40)}`)
    console.log('CLS BREAKDOWN')
    console.log(`${'─'.repeat(40)}`)
    for (const entry of metrics.clsEntries.slice(0, 5)) {
      console.log(`  Shift: ${entry.value.toFixed(4)} (${entry.sources.join(', ') || 'unknown source'})`)
    }
  }
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes}B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
  return `${(bytes / (1024 * 1024)).toFixed(2)}MB`
}

function printComparisonTable(results) {
  console.log(`\n${'='.repeat(100)}`)
  console.log('COMPARISON TABLE')
  console.log(`${'='.repeat(100)}`)

  // Header
  const header = 'URL'.padEnd(40) + 'LCP'.padEnd(12) + 'CLS'.padEnd(12) + 'FCP'.padEnd(12) + 'TTFB'.padEnd(12) + 'Load'
  console.log('\n' + header)
  console.log('─'.repeat(100))

  for (const result of results) {
    let displayUrl = result.url.replace('https://everything2.com', '')
    if (displayUrl.length > 38) displayUrl = displayUrl.substring(0, 35) + '...'

    const lcp = formatMetric('', result.metrics.lcp).replace(': ', '').padEnd(20)
    const cls = formatMetric('', result.metrics.cls).replace(': ', '').padEnd(20)
    const fcp = formatMetric('', result.metrics.fcp).replace(': ', '').padEnd(20)
    const ttfb = formatMetric('', result.metrics.ttfb).replace(': ', '').padEnd(20)
    const load = formatMetric('', result.metrics.load).replace(': ', '')

    console.log(`${displayUrl.padEnd(40)}${lcp}${cls}${fcp}${ttfb}${load}`)
  }
}

async function main() {
  const args = process.argv.slice(2)

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(`
Performance Metrics Tool

Uses Puppeteer to measure real performance metrics from the browser.

Usage:
  node tools/perf-metrics.js [url]                 Analyze URL (mobile viewport)
  node tools/perf-metrics.js [url] --desktop       Desktop viewport
  node tools/perf-metrics.js [url] --both          Both mobile and desktop
  node tools/perf-metrics.js --top-pages           Analyze top E2 pages

Metrics:
  LCP  - Largest Contentful Paint: When main content loads (< 2.5s good)
  CLS  - Cumulative Layout Shift: Visual stability (< 0.1 good)
  TBT  - Total Blocking Time: Main thread blocking (< 200ms good)
  FCP  - First Contentful Paint: When first content appears (< 1.8s good)
  TTFB - Time to First Byte: Server response time (< 800ms good)

Note: Results are from a single page load. Run multiple times for more accurate results.
`)
    process.exit(0)
  }

  if (args.includes('--top-pages')) {
    console.log('Analyzing top traffic pages...\n')

    const results = []
    for (const url of TOP_PAGES) {
      console.log(`Measuring: ${url}`)
      try {
        const metrics = await measurePerformance(url, 'mobile')
        results.push({ url, metrics })
        printResults(url, 'mobile', metrics)
      } catch (err) {
        console.error(`Failed: ${err.message}`)
      }
    }

    if (results.length > 1) {
      printComparisonTable(results)
    }
    return
  }

  const url = args.find(arg => arg.startsWith('http'))
  if (!url) {
    console.error('Please provide a URL to analyze')
    process.exit(1)
  }

  const viewports = []
  if (args.includes('--both')) {
    viewports.push('mobile', 'desktop')
  } else if (args.includes('--desktop')) {
    viewports.push('desktop')
  } else {
    viewports.push('mobile')
  }

  for (const viewport of viewports) {
    console.log(`Measuring ${viewport}...`)
    try {
      const metrics = await measurePerformance(url, viewport)
      printResults(url, viewport, metrics)
    } catch (err) {
      console.error(`Failed (${viewport}): ${err.message}`)
    }
  }
}

main().catch(err => {
  console.error('Fatal error:', err.message)
  process.exit(1)
})
