#!/usr/bin/env node
/**
 * CLS (Cumulative Layout Shift) Debug Tool
 *
 * Analyzes what's causing layout shifts on a page with detailed element info.
 * Takes screenshots before/after shifts to visualize the problem.
 *
 * Usage:
 *   node tools/cls-debug.js [url]
 *   node tools/cls-debug.js [url] --desktop
 */

const puppeteer = require('puppeteer')
const path = require('path')
const fs = require('fs')

const VIEWPORTS = {
  mobile: { width: 375, height: 667, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  desktop: { width: 1920, height: 1080, deviceScaleFactor: 1, isMobile: false, hasTouch: false },
}

async function analyzeCLS(url, viewport = 'mobile') {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
  })

  const outputDir = '/tmp/cls-debug'
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true })
  }

  try {
    const page = await browser.newPage()
    await page.setViewport(VIEWPORTS[viewport])

    if (viewport === 'mobile') {
      await page.setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15')
    }

    // Inject CLS observer before navigation
    await page.evaluateOnNewDocument(() => {
      window.__clsData = {
        shifts: [],
        totalCLS: 0,
      }

      // Create observer immediately when page starts loading
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) {
            const shiftInfo = {
              value: entry.value,
              startTime: entry.startTime,
              sources: [],
            }

            if (entry.sources) {
              for (const source of entry.sources) {
                const node = source.node
                if (node) {
                  shiftInfo.sources.push({
                    tagName: node.tagName,
                    id: node.id || '',
                    className: node.className || '',
                    textContent: (node.textContent || '').substring(0, 50),
                    rect: {
                      previousRect: source.previousRect,
                      currentRect: source.currentRect,
                    },
                  })
                }
              }
            }

            window.__clsData.shifts.push(shiftInfo)
            window.__clsData.totalCLS += entry.value
          }
        }
      })

      observer.observe({ type: 'layout-shift', buffered: true })
    })

    // Take screenshot at different stages
    console.log('Loading page...')

    // Navigate and capture at stages
    const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 })

    // Screenshot after DOM ready
    await page.screenshot({ path: path.join(outputDir, '1-dom-ready.png'), fullPage: false })
    console.log('Screenshot 1: DOM ready')

    // Wait for network idle
    await page.waitForNetworkIdle({ timeout: 30000 }).catch(() => {})
    await page.screenshot({ path: path.join(outputDir, '2-network-idle.png'), fullPage: false })
    console.log('Screenshot 2: Network idle')

    // Wait additional time for late shifts
    await new Promise(resolve => setTimeout(resolve, 3000))
    await page.screenshot({ path: path.join(outputDir, '3-settled.png'), fullPage: false })
    console.log('Screenshot 3: Settled')

    // Get CLS data
    const clsData = await page.evaluate(() => window.__clsData)

    // Get page structure info
    const pageStructure = await page.evaluate(() => {
      const getElementInfo = (el, depth = 0) => {
        if (depth > 3) return null
        const rect = el.getBoundingClientRect()
        const style = window.getComputedStyle(el)

        return {
          tag: el.tagName,
          id: el.id || '',
          class: el.className || '',
          rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height },
          hasMinHeight: style.minHeight !== '0px' && style.minHeight !== 'auto',
          minHeight: style.minHeight,
          position: style.position,
          display: style.display,
        }
      }

      // Get key layout elements
      const header = document.querySelector('header, .header, #header, [class*="header"]')
      const main = document.querySelector('main, .main, #main, [class*="content"]')
      const sidebar = document.querySelector('aside, .sidebar, #sidebar, [class*="nodelet"], [class*="sidebar"]')
      const footer = document.querySelector('footer, .footer, #footer, [class*="footer"]')

      // Get elements that might cause shifts
      const asyncElements = document.querySelectorAll('[data-loading], .loading, [class*="async"]')
      const images = document.querySelectorAll('img:not([width]):not([height])')
      const iframes = document.querySelectorAll('iframe')
      const ads = document.querySelectorAll('[class*="ad"], [id*="ad"], ins.adsbygoogle')

      return {
        header: header ? getElementInfo(header) : null,
        main: main ? getElementInfo(main) : null,
        sidebar: sidebar ? getElementInfo(sidebar) : null,
        footer: footer ? getElementInfo(footer) : null,
        imagesWithoutDimensions: images.length,
        iframes: iframes.length,
        ads: ads.length,
        bodyHeight: document.body.scrollHeight,
        viewportHeight: window.innerHeight,
      }
    })

    // Analyze fonts
    const fontInfo = await page.evaluate(() => {
      const fonts = []
      document.fonts.forEach(font => {
        fonts.push({
          family: font.family,
          status: font.status,
          display: font.display,
        })
      })
      return fonts
    })

    // Get resource timing for late-loading resources
    const lateResources = await page.evaluate(() => {
      const resources = performance.getEntriesByType('resource')
      return resources
        .filter(r => r.startTime > 500) // Resources that started loading after 500ms
        .map(r => ({
          name: r.name.split('/').pop().substring(0, 40),
          type: r.initiatorType,
          startTime: Math.round(r.startTime),
          duration: Math.round(r.duration),
        }))
        .slice(0, 20)
    })

    return { clsData, pageStructure, fontInfo, lateResources, outputDir }
  } finally {
    await browser.close()
  }
}

function printResults(results) {
  const { clsData, pageStructure, fontInfo, lateResources, outputDir } = results

  console.log(`\n${'='.repeat(70)}`)
  console.log('CLS DEBUG REPORT')
  console.log(`${'='.repeat(70)}`)

  // Total CLS
  const clsRating = clsData.totalCLS <= 0.1 ? '\x1b[32mGood\x1b[0m' :
    clsData.totalCLS <= 0.25 ? '\x1b[33mNeeds Improvement\x1b[0m' : '\x1b[31mPoor\x1b[0m'
  console.log(`\nTotal CLS: ${clsData.totalCLS.toFixed(4)} (${clsRating})`)
  console.log(`Number of shifts: ${clsData.shifts.length}`)

  // Individual shifts
  if (clsData.shifts.length > 0) {
    console.log(`\n${'─'.repeat(50)}`)
    console.log('LAYOUT SHIFTS (in order of occurrence)')
    console.log(`${'─'.repeat(50)}`)

    for (let i = 0; i < Math.min(clsData.shifts.length, 10); i++) {
      const shift = clsData.shifts[i]
      console.log(`\n[Shift ${i + 1}] Value: ${shift.value.toFixed(4)} at ${Math.round(shift.startTime)}ms`)

      if (shift.sources.length > 0) {
        for (const source of shift.sources) {
          const identifier = source.id ? `#${source.id}` :
            source.className ? `.${source.className.split(' ')[0]}` : ''
          console.log(`  Element: <${source.tagName}${identifier}>`)

          if (source.textContent) {
            console.log(`  Content: "${source.textContent.trim().substring(0, 40)}..."`)
          }

          if (source.rect.previousRect && source.rect.currentRect) {
            const prev = source.rect.previousRect
            const curr = source.rect.currentRect
            const yShift = curr.y - prev.y
            const heightChange = curr.height - prev.height

            if (Math.abs(yShift) > 1) {
              console.log(`  Moved: ${yShift > 0 ? 'down' : 'up'} by ${Math.abs(Math.round(yShift))}px`)
            }
            if (Math.abs(heightChange) > 1) {
              console.log(`  Height: ${heightChange > 0 ? 'grew' : 'shrank'} by ${Math.abs(Math.round(heightChange))}px`)
            }
          }
        }
      } else {
        console.log('  (No source elements captured - shift may be from viewport change)')
      }
    }
  }

  // Page structure analysis
  console.log(`\n${'─'.repeat(50)}`)
  console.log('PAGE STRUCTURE ANALYSIS')
  console.log(`${'─'.repeat(50)}`)

  if (pageStructure.header) {
    console.log(`\nHeader:`)
    console.log(`  Height: ${Math.round(pageStructure.header.rect.height)}px`)
    console.log(`  Has min-height: ${pageStructure.header.hasMinHeight ? 'Yes (' + pageStructure.header.minHeight + ')' : 'NO ⚠️'}`)
  }

  if (pageStructure.sidebar) {
    console.log(`\nSidebar:`)
    console.log(`  Position: ${pageStructure.sidebar.position}`)
    console.log(`  Has min-height: ${pageStructure.sidebar.hasMinHeight ? 'Yes' : 'NO ⚠️'}`)
  }

  console.log(`\nPotential CLS sources:`)
  console.log(`  Images without dimensions: ${pageStructure.imagesWithoutDimensions} ${pageStructure.imagesWithoutDimensions > 0 ? '⚠️' : '✓'}`)
  console.log(`  Iframes: ${pageStructure.iframes}`)
  console.log(`  Ad slots: ${pageStructure.ads}`)

  // Font analysis
  console.log(`\n${'─'.repeat(50)}`)
  console.log('FONT LOADING')
  console.log(`${'─'.repeat(50)}`)

  const loadedFonts = fontInfo.filter(f => f.status === 'loaded')
  const pendingFonts = fontInfo.filter(f => f.status !== 'loaded')

  console.log(`Loaded: ${loadedFonts.length}`)
  if (pendingFonts.length > 0) {
    console.log(`Pending/Failed: ${pendingFonts.length} ⚠️`)
    pendingFonts.forEach(f => console.log(`  - ${f.family}: ${f.status}`))
  }

  // Late resources
  if (lateResources.length > 0) {
    console.log(`\n${'─'.repeat(50)}`)
    console.log('LATE-LOADING RESOURCES (started after 500ms)')
    console.log(`${'─'.repeat(50)}`)

    for (const r of lateResources.slice(0, 10)) {
      console.log(`  [${r.startTime}ms] ${r.type}: ${r.name} (${r.duration}ms)`)
    }
  }

  // Screenshots location
  console.log(`\n${'─'.repeat(50)}`)
  console.log('SCREENSHOTS')
  console.log(`${'─'.repeat(50)}`)
  console.log(`Saved to: ${outputDir}/`)
  console.log('  1-dom-ready.png   - After DOM loaded')
  console.log('  2-network-idle.png - After network idle')
  console.log('  3-settled.png     - After 3s settle time')

  // Recommendations
  console.log(`\n${'─'.repeat(50)}`)
  console.log('RECOMMENDATIONS')
  console.log(`${'─'.repeat(50)}`)

  const recommendations = []

  if (clsData.totalCLS > 0.1) {
    // Analyze the biggest shifts
    const bigShifts = clsData.shifts.filter(s => s.value > 0.05)

    if (bigShifts.some(s => s.sources.some(src => src.tagName === 'HEADER' || src.className?.includes('header')))) {
      recommendations.push('Add min-height to header to prevent collapse/expansion during load')
    }

    if (bigShifts.some(s => s.sources.some(src => src.tagName === 'DIV' && !src.id && !src.className))) {
      recommendations.push('Identify and add dimensions to containers loading async content')
    }

    if (pageStructure.imagesWithoutDimensions > 0) {
      recommendations.push(`Add width/height attributes to ${pageStructure.imagesWithoutDimensions} images`)
    }

    if (pageStructure.ads > 0) {
      recommendations.push('Reserve fixed space for ad slots using min-height')
    }

    if (!pageStructure.sidebar?.hasMinHeight) {
      recommendations.push('Add min-height to sidebar/nodelet container')
    }
  }

  if (recommendations.length === 0) {
    console.log('  CLS is acceptable - no major issues detected')
  } else {
    recommendations.forEach((r, i) => console.log(`  ${i + 1}. ${r}`))
  }
}

async function main() {
  const args = process.argv.slice(2)

  if (args.length === 0 || args.includes('--help')) {
    console.log(`
CLS Debug Tool - Analyze what's causing layout shifts

Usage:
  node tools/cls-debug.js [url]           Analyze mobile viewport
  node tools/cls-debug.js [url] --desktop Analyze desktop viewport

Output:
  - Detailed breakdown of each layout shift
  - Elements causing shifts with their movement
  - Screenshots at different load stages
  - Recommendations to fix issues
`)
    process.exit(0)
  }

  const url = args.find(arg => arg.startsWith('http'))
  if (!url) {
    console.error('Please provide a URL')
    process.exit(1)
  }

  const viewport = args.includes('--desktop') ? 'desktop' : 'mobile'

  console.log(`Analyzing CLS for ${url} (${viewport} viewport)...`)

  try {
    const results = await analyzeCLS(url, viewport)
    printResults(results)
  } catch (err) {
    console.error('Error:', err.message)
    process.exit(1)
  }
}

main()
