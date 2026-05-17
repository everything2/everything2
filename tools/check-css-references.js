#!/usr/bin/env node

/**
 * CSS Reference Check
 *
 * Round-trip validation between JS `className` references and CSS class definitions.
 * Catches the two common refactor failure modes:
 *
 *   - JS references a class that no CSS defines  → dropped style during refactor (bug)
 *   - CSS defines a class no JS references       → dead CSS, candidate for cleanup
 *
 * Works on the convention that all CSS lives in www/css/*.css and all React
 * components live under react/. Does not parse JS — uses regex extraction of
 * className literals, which means dynamic/computed classes are skipped.
 *
 * Usage:
 *   node tools/check-css-references.js              # Full human report
 *   node tools/check-css-references.js --json       # JSON output
 *   node tools/check-css-references.js --missing    # Only show classes used but not defined
 *   node tools/check-css-references.js --orphans    # Only show CSS classes with no JS consumer
 *   node tools/check-css-references.js --verbose    # Per-file breakdown
 *
 * Exit code: 0 if clean, 1 if any classes are referenced but undefined
 */

const fs = require('fs')
const path = require('path')

const REPO_ROOT = path.resolve(__dirname, '..')
const CSS_DIR = path.join(REPO_ROOT, 'www', 'css')
const JS_ROOTS = [path.join(REPO_ROOT, 'react')]

// ─── CSS class extraction ──────────────────────────────────────────────────

function extractCssClasses(filePath) {
  const content = fs.readFileSync(filePath, 'utf8')

  // Strip comments first (greedy block + line)
  const stripped = content.replace(/\/\*[\s\S]*?\*\//g, '')

  // Match class selectors: .foo, .foo-bar, .foo__elem, .foo--mod, .foo__elem--mod
  // Word boundaries handle .foo:hover, .foo>.bar, .foo[disabled], etc.
  const classRegex = /\.(-?[_a-zA-Z]+[_a-zA-Z0-9-]*)/g

  const classes = new Set()
  let match
  while ((match = classRegex.exec(stripped)) !== null) {
    // Skip media-query syntax like .25em (not a class)
    if (/^\d/.test(match[1])) continue
    classes.add(match[1])
  }
  return classes
}

function loadAllCssClasses() {
  const cssFiles = fs.readdirSync(CSS_DIR).filter(f => f.endsWith('.css'))
  const byFile = {}
  const all = new Set()
  for (const f of cssFiles) {
    const filePath = path.join(CSS_DIR, f)
    const classes = extractCssClasses(filePath)
    byFile[f] = classes
    for (const c of classes) all.add(c)
  }
  return { all, byFile }
}

// ─── JS className extraction ───────────────────────────────────────────────

/**
 * Walk a directory recursively, return all .js/.jsx files.
 */
function walkJs(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') || entry.name === 'node_modules') continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walkJs(full, out)
    else if (/\.(jsx?|tsx?)$/.test(entry.name)) out.push(full)
  }
  return out
}

/**
 * Extract every string literal that appears anywhere a className value could be.
 * We're deliberately permissive — collect all literal class strings appearing
 * in or near className= constructs, then tokenize by whitespace.
 *
 * Captures:
 *   className="foo bar"            → "foo", "bar"
 *   className='foo'                → "foo"
 *   className={'foo'}              → "foo"
 *   className={`foo ${x}`}         → "foo"
 *   className={cond ? 'a' : 'b'}   → "a", "b"
 *   classnames('foo', { bar: x })  → "foo", "bar"
 *
 * Skips: variable references, expressions, computed class strings
 */
function extractJsClassRefs(filePath) {
  const content = fs.readFileSync(filePath, 'utf8')
  const refs = new Set()

  // Strategy: find every className= occurrence and gobble forward to the
  // closing }, then extract string literals from that span. Also handle
  // classnames() / clsx() / cn() helper calls.
  const className_regex = /className\s*=\s*(["']([^"']*)["']|\{([^}]*(?:\{[^}]*\}[^}]*)*)\})/g
  let m
  while ((m = className_regex.exec(content)) !== null) {
    const value = m[2] !== undefined ? m[2] : m[3]
    if (value === undefined) continue
    // Extract string literals from the value
    const stringRe = /["'`]([^"'`]+)["'`]/g
    let s
    while ((s = stringRe.exec(value)) !== null) {
      for (const cls of s[1].split(/\s+/)) {
        if (cls && /^[_a-zA-Z][_a-zA-Z0-9-]*$/.test(cls)) refs.add(cls)
      }
    }
  }

  // Classnames helper invocations: classnames('a', 'b', { c: cond }, ...)
  const helper_regex = /\b(?:classnames|clsx|cn)\s*\(([^)]+)\)/g
  while ((m = helper_regex.exec(content)) !== null) {
    const args = m[1]
    const stringRe = /["'`]([^"'`]+)["'`]/g
    let s
    while ((s = stringRe.exec(args)) !== null) {
      for (const cls of s[1].split(/\s+/)) {
        if (cls && /^[_a-zA-Z][_a-zA-Z0-9-]*$/.test(cls)) refs.add(cls)
      }
    }
    // Object keys in helper calls: { 'foo-bar': cond, baz: cond }
    const keyRe = /(?:^|[{,])\s*['"]?([_a-zA-Z][_a-zA-Z0-9-]*)['"]?\s*:/g
    let k
    while ((k = keyRe.exec(args)) !== null) {
      refs.add(k[1])
    }
  }

  return refs
}

function loadAllJsRefs() {
  const byFile = {}
  const all = new Set()
  for (const root of JS_ROOTS) {
    if (!fs.existsSync(root)) continue
    for (const f of walkJs(root)) {
      const refs = extractJsClassRefs(f)
      if (refs.size > 0) {
        byFile[path.relative(REPO_ROOT, f)] = refs
        for (const r of refs) all.add(r)
      }
    }
  }
  return { all, byFile }
}

// ─── Cross-reference ───────────────────────────────────────────────────────

function diffSets(jsRefs, cssClasses) {
  const usedButUndefined = new Set()
  const definedButUnused = new Set()
  for (const r of jsRefs.all) {
    if (!cssClasses.all.has(r)) usedButUndefined.add(r)
  }
  for (const c of cssClasses.all) {
    if (!jsRefs.all.has(c)) definedButUnused.add(c)
  }
  return { usedButUndefined, definedButUnused }
}

/**
 * For each missing class, find which JS files reference it (so user can fix).
 */
function findReferences(className, byFile) {
  const files = []
  for (const [f, refs] of Object.entries(byFile)) {
    if (refs.has(className)) files.push(f)
  }
  return files
}

// ─── Output ────────────────────────────────────────────────────────────────

const COLORS = {
  red: '\x1b[31m', yellow: '\x1b[33m', green: '\x1b[32m',
  cyan: '\x1b[36m', dim: '\x1b[2m', bold: '\x1b[1m', reset: '\x1b[0m',
}

function printReport(jsRefs, cssClasses, diff, opts) {
  const { verbose, missingOnly, orphansOnly } = opts

  if (!missingOnly && !orphansOnly) {
    console.log(`\n${'═'.repeat(70)}`)
    console.log(`${COLORS.bold}CSS REFERENCE CHECK${COLORS.reset}`)
    console.log(`${'═'.repeat(70)}\n`)
    console.log(`CSS files scanned: ${Object.keys(cssClasses.byFile).length}`)
    console.log(`Distinct CSS classes defined: ${cssClasses.all.size}`)
    console.log(`JS files with className refs: ${Object.keys(jsRefs.byFile).length}`)
    console.log(`Distinct className refs in JS: ${jsRefs.all.size}`)
    console.log('')
    console.log(`${COLORS.bold}Used in JS, not defined in CSS:${COLORS.reset} ${diff.usedButUndefined.size > 0 ? COLORS.red : COLORS.green}${diff.usedButUndefined.size}${COLORS.reset}`)
    console.log(`${COLORS.bold}Defined in CSS, not used in JS:${COLORS.reset} ${COLORS.dim}${diff.definedButUnused.size}${COLORS.reset}`)
  }

  if (!orphansOnly && diff.usedButUndefined.size > 0) {
    console.log(`\n${COLORS.red}${COLORS.bold}── Missing CSS (potential dropped styles) ──${COLORS.reset}`)
    const sorted = [...diff.usedButUndefined].sort()
    for (const cls of sorted) {
      const refs = findReferences(cls, jsRefs.byFile)
      console.log(`  ${COLORS.red}${cls}${COLORS.reset}`)
      if (verbose || refs.length <= 3) {
        for (const r of refs) console.log(`    ${COLORS.dim}${r}${COLORS.reset}`)
      } else {
        console.log(`    ${COLORS.dim}${refs.slice(0, 2).join(', ')} (+${refs.length - 2} more)${COLORS.reset}`)
      }
    }
  }

  if (!missingOnly && diff.definedButUnused.size > 0 && verbose) {
    console.log(`\n${COLORS.yellow}${COLORS.bold}── CSS defined but not referenced from JS ──${COLORS.reset}`)
    console.log(`  ${COLORS.dim}(note: may still be used from server-rendered HTML in ecore/Everything/*.pm)${COLORS.reset}`)
    const sorted = [...diff.definedButUnused].sort()
    for (const cls of sorted.slice(0, 100)) {
      console.log(`  ${COLORS.yellow}${cls}${COLORS.reset}`)
    }
    if (sorted.length > 100) {
      console.log(`  ${COLORS.dim}... and ${sorted.length - 100} more${COLORS.reset}`)
    }
  }
  console.log('')
}

// ─── Main ──────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2)
  if (args.includes('--help')) {
    console.log(`
CSS Reference Check — round-trip validation between JS className refs and CSS

  --missing    Only show classes used in JS but not defined in CSS (the critical signal)
  --orphans    Only show CSS classes never referenced in JS
  --verbose    Per-file breakdown plus full orphan list
  --json       Emit JSON instead of human report

Exit code: 0 if no missing-CSS issues, 1 otherwise.
`)
    process.exit(0)
  }

  const opts = {
    verbose: args.includes('--verbose'),
    missingOnly: args.includes('--missing'),
    orphansOnly: args.includes('--orphans'),
    json: args.includes('--json'),
  }

  const cssClasses = loadAllCssClasses()
  const jsRefs = loadAllJsRefs()
  const diff = diffSets(jsRefs, cssClasses)

  if (opts.json) {
    console.log(JSON.stringify({
      summary: {
        cssClassCount: cssClasses.all.size,
        jsRefCount: jsRefs.all.size,
        usedButUndefined: diff.usedButUndefined.size,
        definedButUnused: diff.definedButUnused.size,
      },
      missing: [...diff.usedButUndefined].sort().map(c => ({
        class: c,
        referencedIn: findReferences(c, jsRefs.byFile),
      })),
      orphans: [...diff.definedButUnused].sort(),
    }, null, 2))
  } else {
    printReport(jsRefs, cssClasses, diff, opts)
  }

  process.exit(diff.usedButUndefined.size > 0 ? 1 : 0)
}

main()
