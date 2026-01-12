#!/usr/bin/env node
/**
 * Extract SVG paths from the Decipher font for "e" and "2" characters
 * Used to generate the E2Logo SVG component
 */

const opentype = require('opentype.js')
const path = require('path')

const fontPath = path.join(__dirname, '../assets/branding/decipher.ttf')

async function extractPaths() {
  const font = await opentype.load(fontPath)

  console.log('Font:', font.names.fullName?.en || 'Unknown')
  console.log('Units per Em:', font.unitsPerEm)
  console.log()

  // Get glyphs for 'e' and '2'
  const chars = ['e', '2']

  for (const char of chars) {
    const glyph = font.charToGlyph(char)

    console.log(`\n=== Character: "${char}" ===`)
    console.log(`Glyph index: ${glyph.index}`)
    console.log(`Advance width: ${glyph.advanceWidth}`)

    // Get the path data
    // Render at a reasonable size for mobile (target ~32px height)
    const targetHeight = 32
    const scale = targetHeight / font.unitsPerEm

    // Get path at origin
    const path = glyph.getPath(0, 0, font.unitsPerEm)

    // Get bounding box
    const bbox = path.getBoundingBox()
    console.log(`Bounding box: x1=${bbox.x1.toFixed(1)}, y1=${bbox.y1.toFixed(1)}, x2=${bbox.x2.toFixed(1)}, y2=${bbox.y2.toFixed(1)}`)
    console.log(`Width: ${(bbox.x2 - bbox.x1).toFixed(1)}, Height: ${(bbox.y2 - bbox.y1).toFixed(1)}`)

    // Generate SVG path data (flip Y axis since fonts have Y going up)
    const scaledPath = glyph.getPath(0, targetHeight, targetHeight)
    const svgPath = scaledPath.toSVG(2)

    console.log(`\nSVG (${targetHeight}px height):`)
    console.log(svgPath)

    // Also generate with proper baseline alignment
    const ascender = font.ascender
    const descender = font.descender
    const baseline = (ascender / font.unitsPerEm) * targetHeight

    console.log(`\nFont metrics: ascender=${ascender}, descender=${descender}`)
    console.log(`Baseline at: ${baseline.toFixed(1)}px from top`)
  }

  // Generate a combined SVG showing both characters
  console.log('\n\n=== Combined e2 Logo SVG ===')

  const eGlyph = font.charToGlyph('e')
  const twoGlyph = font.charToGlyph('2')

  const size = 32
  const eWidth = (eGlyph.advanceWidth / font.unitsPerEm) * size
  const twoWidth = (twoGlyph.advanceWidth / font.unitsPerEm) * size
  const gap = 2

  // Position the 2 after the e
  const ePath = eGlyph.getPath(0, size, size)
  const twoPath = twoGlyph.getPath(eWidth + gap, size, size)

  console.log(`<svg width="${Math.ceil(eWidth + gap + twoWidth)}" height="${size}" viewBox="0 0 ${Math.ceil(eWidth + gap + twoWidth)} ${size}" fill="none" xmlns="http://www.w3.org/2000/svg">`)
  console.log(`  <!-- "e" -->`)
  console.log(`  <path d="${ePath.toPathData(2)}" fill="#fff"/>`)
  console.log(`  <!-- "2" -->`)
  console.log(`  <path d="${twoPath.toPathData(2)}" fill="#5dd6e4"/>`)
  console.log(`</svg>`)
}

extractPaths().catch(err => {
  console.error('Error:', err.message)
  process.exit(1)
})
