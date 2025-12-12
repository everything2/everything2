#!/usr/bin/env node
/**
 * compare-link-parsing.js
 *
 * Compares server-side Perl parseLinks() output against client-side
 * E2HtmlSanitizer.js parseE2Links() output to find edge cases.
 *
 * Usage:
 *   node tools/compare-link-parsing.js writeup-content-dump.json
 *   node tools/compare-link-parsing.js --verbose sample.json
 *   node tools/compare-link-parsing.js --output-mismatches mismatches.json sample.json
 *
 * Input: JSON file from extract-writeup-content.pl with --include-parsed
 * Output: Report of differences between server and client parsing
 */

const fs = require('fs')
const path = require('path')

// Import the E2HtmlSanitizer (we need to handle the import carefully)
// Since it's an ES module, we'll inline the parsing logic here for Node compatibility

/**
 * Parse E2 [link] syntax into HTML anchor tags
 * This is a copy of parseE2Links from E2HtmlSanitizer.js for Node.js usage
 */
function parseE2Links(text) {
  if (!text) return ''

  // First pass: Handle [nodetitle[nodetype]] format (typed links)
  let result = text.replace(
    /\[([^\[\]|]+?)\s*\[\s*([^\[\]]+?)\s*\]\]/g,
    (match, title, nodetype) => {
      const trimmedTitle = title.trim()
      const trimmedType = nodetype.trim().toLowerCase()
      if (!trimmedTitle || !trimmedType) return match

      const encodedTitle = encodeURIComponent(trimmedTitle)
      return `<a href="/${trimmedType}/${encodedTitle}" class="e2-link">${escapeHtml(trimmedTitle)}</a>`
    }
  )

  // Second pass: Handle [title] and [title|display] format (standard links)
  result = result.replace(
    /\[([^\[\]|]+)(?:\|([^\[\]]+))?\]/g,
    (match, title, displayText) => {
      const trimmedTitle = title.trim()
      if (!trimmedTitle) return match

      const display = (displayText || title).trim()
      const encodedTitle = encodeURIComponent(trimmedTitle)
      return `<a href="/title/${encodedTitle}" class="e2-link">${escapeHtml(display)}</a>`
    }
  )

  return result
}

function escapeHtml(text) {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

/**
 * Extract links from text (for analysis without full parsing)
 */
function extractBracketLinks(text) {
  if (!text) return []

  const links = []

  // Typed links: [title[type]]
  const typedPattern = /\[([^\[\]|]+?)\s*\[\s*([^\[\]]+?)\s*\]\]/g
  let match
  while ((match = typedPattern.exec(text)) !== null) {
    links.push({
      full: match[0],
      title: match[1].trim(),
      type: match[2].trim(),
      kind: 'typed'
    })
  }

  // Standard links: [title] or [title|display]
  const standardPattern = /\[([^\[\]|]+)(?:\|([^\[\]]+))?\]/g
  while ((match = standardPattern.exec(text)) !== null) {
    // Skip if this was already matched as part of a typed link
    const isTyped = links.some(l => l.full.includes(match[0]))
    if (!isTyped) {
      links.push({
        full: match[0],
        title: match[1].trim(),
        display: match[2] ? match[2].trim() : null,
        kind: 'standard'
      })
    }
  }

  return links
}

/**
 * Normalize HTML for comparison (remove whitespace differences, normalize attributes)
 */
function normalizeHtml(html) {
  if (!html) return ''
  return html
    .replace(/\s+/g, ' ')
    .replace(/\s*=\s*/g, '=')
    .replace(/>\s+</g, '><')
    .trim()
}

/**
 * Compare two HTML strings, returning differences
 */
function compareHtml(server, client) {
  const normServer = normalizeHtml(server)
  const normClient = normalizeHtml(client)

  if (normServer === normClient) {
    return { match: true }
  }

  return {
    match: false,
    server: normServer,
    client: normClient,
    // Try to identify the specific difference
    diff: findDiff(normServer, normClient)
  }
}

function findDiff(a, b) {
  // Find first point of difference
  let i = 0
  while (i < a.length && i < b.length && a[i] === b[i]) {
    i++
  }

  const contextLen = 50
  const start = Math.max(0, i - contextLen)
  const aContext = a.substring(start, i + contextLen)
  const bContext = b.substring(start, i + contextLen)

  return {
    position: i,
    serverContext: aContext,
    clientContext: bContext
  }
}

/**
 * Analyze a single writeup for parsing differences
 */
function analyzeWriteup(writeup, verbose) {
  const { node_id, title, doctext, parsed_server } = writeup

  // Extract links for analysis
  const links = extractBracketLinks(doctext)

  // If we have server-parsed output, compare it
  let comparison = null
  if (parsed_server) {
    const parsed_client = parseE2Links(doctext)
    comparison = compareHtml(parsed_server, parsed_client)
  }

  return {
    node_id,
    title,
    linkCount: links.length,
    links: verbose ? links : undefined,
    hasTypedLinks: links.some(l => l.kind === 'typed'),
    hasPipeLinks: links.some(l => l.display),
    comparison,
    // Flag potential edge cases
    edgeCases: detectEdgeCases(doctext, links)
  }
}

/**
 * Detect potential edge cases in content
 */
function detectEdgeCases(doctext, links) {
  const cases = []

  if (!doctext) return cases

  // Nested brackets that might confuse parser
  if (/\[\[/.test(doctext)) {
    cases.push('nested_brackets')
  }

  // Unbalanced brackets
  const openCount = (doctext.match(/\[/g) || []).length
  const closeCount = (doctext.match(/\]/g) || []).length
  if (openCount !== closeCount) {
    cases.push('unbalanced_brackets')
  }

  // Links containing special characters
  if (links.some(l => /[<>"']/.test(l.title))) {
    cases.push('special_chars_in_link')
  }

  // Links with HTML entities
  if (links.some(l => /&\w+;/.test(l.title))) {
    cases.push('html_entities_in_link')
  }

  // Links containing pipe inside title (ambiguous)
  if (/\[[^\]]*\|[^\]]*\|/.test(doctext)) {
    cases.push('multiple_pipes_in_link')
  }

  // Empty brackets
  if (/\[\s*\]/.test(doctext)) {
    cases.push('empty_brackets')
  }

  // Brackets in code blocks (should not be parsed)
  if (/<code[^>]*>.*?\[.*?\].*?<\/code>/is.test(doctext)) {
    cases.push('brackets_in_code')
  }

  // Brackets in pre blocks
  if (/<pre[^>]*>.*?\[.*?\].*?<\/pre>/is.test(doctext)) {
    cases.push('brackets_in_pre')
  }

  // Very long link titles (>100 chars)
  if (links.some(l => l.title && l.title.length > 100)) {
    cases.push('very_long_link_title')
  }

  // Links with newlines
  if (links.some(l => l.full && /\n/.test(l.full))) {
    cases.push('newline_in_link')
  }

  return cases
}

/**
 * Main analysis function
 */
function analyze(inputFile, options) {
  const { verbose, outputMismatches } = options

  console.error(`Reading ${inputFile}...`)
  const data = JSON.parse(fs.readFileSync(inputFile, 'utf8'))

  console.error(`Analyzing ${data.count} writeups...`)

  const results = {
    analyzed_at: new Date().toISOString(),
    input_file: inputFile,
    total_writeups: data.count,
    has_server_parsed: data.query?.include_parsed || false,

    // Statistics
    stats: {
      with_links: 0,
      with_typed_links: 0,
      with_pipe_links: 0,
      total_links: 0,
      mismatches: 0,
    },

    // Edge cases found
    edge_cases: {},

    // Mismatches (if server-parsed data available)
    mismatches: [],

    // Sample of each edge case type
    edge_case_samples: {}
  }

  for (const writeup of data.writeups) {
    const analysis = analyzeWriteup(writeup, verbose)

    if (analysis.linkCount > 0) {
      results.stats.with_links++
      results.stats.total_links += analysis.linkCount
    }

    if (analysis.hasTypedLinks) {
      results.stats.with_typed_links++
    }

    if (analysis.hasPipeLinks) {
      results.stats.with_pipe_links++
    }

    // Track edge cases
    for (const edgeCase of analysis.edgeCases) {
      results.edge_cases[edgeCase] = (results.edge_cases[edgeCase] || 0) + 1

      // Keep first sample of each edge case
      if (!results.edge_case_samples[edgeCase]) {
        results.edge_case_samples[edgeCase] = {
          node_id: analysis.node_id,
          title: analysis.title,
          links: analysis.links?.slice(0, 5) // First 5 links
        }
      }
    }

    // Track mismatches
    if (analysis.comparison && !analysis.comparison.match) {
      results.stats.mismatches++
      results.mismatches.push({
        node_id: analysis.node_id,
        title: analysis.title,
        diff: analysis.comparison.diff,
        serverSnippet: analysis.comparison.server?.substring(0, 500),
        clientSnippet: analysis.comparison.client?.substring(0, 500)
      })
    }
  }

  // Output results
  console.log(JSON.stringify(results, null, 2))

  // Optionally output full mismatches to separate file
  if (outputMismatches && results.mismatches.length > 0) {
    fs.writeFileSync(outputMismatches, JSON.stringify(results.mismatches, null, 2))
    console.error(`Wrote ${results.mismatches.length} mismatches to ${outputMismatches}`)
  }

  // Summary to stderr
  console.error('\n=== Summary ===')
  console.error(`Total writeups: ${results.total_writeups}`)
  console.error(`With links: ${results.stats.with_links}`)
  console.error(`Total links: ${results.stats.total_links}`)
  console.error(`With typed links [title[type]]: ${results.stats.with_typed_links}`)
  console.error(`With pipe links [title|display]: ${results.stats.with_pipe_links}`)

  if (results.has_server_parsed) {
    console.error(`Parsing mismatches: ${results.stats.mismatches}`)
  }

  console.error('\nEdge cases found:')
  for (const [edgeCase, count] of Object.entries(results.edge_cases).sort((a, b) => b[1] - a[1])) {
    console.error(`  ${edgeCase}: ${count}`)
  }
}

// CLI
const args = process.argv.slice(2)
let verbose = false
let outputMismatches = null
let inputFile = null

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--verbose' || args[i] === '-v') {
    verbose = true
  } else if (args[i] === '--output-mismatches' || args[i] === '-o') {
    outputMismatches = args[++i]
  } else if (args[i] === '--help' || args[i] === '-h') {
    console.log(`
Usage: node compare-link-parsing.js [OPTIONS] <input.json>

Options:
  --verbose, -v              Include full link details in output
  --output-mismatches, -o    Write mismatches to separate file
  --help, -h                 Show this help

Input file should be JSON from extract-writeup-content.pl
For mismatch detection, use --include-parsed when extracting.

Examples:
  # Extract sample with server-parsed output
  docker exec e2devapp perl /var/everything/tools/extract-writeup-content.pl \\
    --limit 1000 --include-parsed > sample.json

  # Analyze for edge cases
  node tools/compare-link-parsing.js sample.json

  # Full analysis with mismatch output
  node tools/compare-link-parsing.js -v -o mismatches.json sample.json
`)
    process.exit(0)
  } else if (!args[i].startsWith('-')) {
    inputFile = args[i]
  }
}

if (!inputFile) {
  console.error('Error: No input file specified. Use --help for usage.')
  process.exit(1)
}

if (!fs.existsSync(inputFile)) {
  console.error(`Error: File not found: ${inputFile}`)
  process.exit(1)
}

analyze(inputFile, { verbose, outputMismatches })
