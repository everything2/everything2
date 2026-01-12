#!/usr/bin/env node
/**
 * Mobile Audit Tool for Everything2 React Components
 *
 * Scans React document components for common mobile optimization issues:
 * 1. Duplicate H1 tags (component has H1 when PageHeader already provides one)
 * 2. Missing useIsMobile hook for responsive styling
 * 3. Hardcoded padding/margin that doesn't account for mobile
 * 4. Fixed widths that could cause horizontal scrolling
 *
 * Usage: node tools/mobile-audit.js [--fix-report]
 */

const fs = require('fs')
const path = require('path')
const glob = require('glob')

const DOCUMENTS_DIR = path.join(__dirname, '../react/components/Documents')

// Patterns to check
const ISSUES = {
  DUPLICATE_H1: {
    pattern: /<h1[^>]*>|<H1[^>]*>/g,
    description: 'Has <h1> tag (may duplicate PageHeader title)',
    severity: 'warning'
  },
  MISSING_USE_IS_MOBILE: {
    pattern: /useIsMobile/,
    inverse: true, // Issue if NOT found
    description: 'Missing useIsMobile hook for responsive styling',
    severity: 'info',
    skipIf: /standalone|fullscreen|chatterlight/i // Skip standalone pages
  },
  HARDCODED_PADDING: {
    pattern: /padding:\s*['"]?\d+px['"]?[^}]*(?!isMobile)/,
    description: 'Has hardcoded padding without mobile check',
    severity: 'info'
  },
  HARDCODED_MAX_WIDTH: {
    pattern: /maxWidth:\s*['"]?\d+px['"]?[^}]*(?!isMobile)/,
    description: 'Has hardcoded maxWidth without mobile check',
    severity: 'info'
  },
  FIXED_WIDTH_STYLE: {
    pattern: /width:\s*['"]?\d+px['"]?/,
    description: 'Has fixed pixel width (may cause overflow)',
    severity: 'info'
  }
}

// Components that are expected to have their own H1 (fullscreen/standalone)
const STANDALONE_COMPONENTS = [
  'Chatterlight.js',
  'Login.js',
  'SignUp.js',
  'ResetPassword.js',
  'GuestFrontPage.js' // Has hero section with intentional H1
]

function auditFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8')
  const fileName = path.basename(filePath)
  const issues = []

  // Check for duplicate H1
  const h1Matches = content.match(ISSUES.DUPLICATE_H1.pattern)
  if (h1Matches && !STANDALONE_COMPONENTS.includes(fileName)) {
    // Check if it's in a return statement (actual render, not comment)
    const lines = content.split('\n')
    const h1Lines = lines.filter(line =>
      /<h1[^>]*>/i.test(line) && !line.trim().startsWith('//') && !line.trim().startsWith('*')
    )
    if (h1Lines.length > 0) {
      issues.push({
        type: 'DUPLICATE_H1',
        ...ISSUES.DUPLICATE_H1,
        count: h1Lines.length,
        lines: h1Lines.map(l => l.trim().substring(0, 60))
      })
    }
  }

  // Check for useIsMobile
  if (!ISSUES.MISSING_USE_IS_MOBILE.skipIf.test(content)) {
    if (!ISSUES.MISSING_USE_IS_MOBILE.pattern.test(content)) {
      // Only flag if component has inline styles
      if (/style\s*=\s*\{/.test(content)) {
        issues.push({
          type: 'MISSING_USE_IS_MOBILE',
          ...ISSUES.MISSING_USE_IS_MOBILE
        })
      }
    }
  }

  // Check for hardcoded dimensions
  // Only check files that don't already use isMobile
  if (!/useIsMobile/.test(content)) {
    // Check for container style with hardcoded padding
    const containerMatch = content.match(/const containerStyle\s*=\s*\{[^}]+\}/s)
    if (containerMatch) {
      if (/padding:\s*['"]?\d+px/.test(containerMatch[0])) {
        issues.push({
          type: 'HARDCODED_PADDING',
          ...ISSUES.HARDCODED_PADDING,
          context: 'containerStyle'
        })
      }
      if (/maxWidth:\s*['"]?\d+px/.test(containerMatch[0])) {
        issues.push({
          type: 'HARDCODED_MAX_WIDTH',
          ...ISSUES.HARDCODED_MAX_WIDTH,
          context: 'containerStyle'
        })
      }
    }
  }

  return issues
}

function audit() {
  const files = glob.sync(path.join(DOCUMENTS_DIR, '*.js'))
  const results = {
    totalFiles: files.length,
    filesWithIssues: 0,
    issuesByType: {},
    details: []
  }

  for (const file of files) {
    const issues = auditFile(file)
    if (issues.length > 0) {
      results.filesWithIssues++
      results.details.push({
        file: path.basename(file),
        issues
      })

      for (const issue of issues) {
        results.issuesByType[issue.type] = (results.issuesByType[issue.type] || 0) + 1
      }
    }
  }

  return results
}

function printResults(results) {
  console.log('\n=== E2 Mobile Optimization Audit ===\n')
  console.log(`Total document components: ${results.totalFiles}`)
  console.log(`Components with issues: ${results.filesWithIssues}`)
  console.log(`Components passing: ${results.totalFiles - results.filesWithIssues}`)

  console.log('\n--- Issues by Type ---')
  for (const [type, count] of Object.entries(results.issuesByType)) {
    const issue = ISSUES[type]
    console.log(`  ${type}: ${count} files`)
  }

  if (results.details.length > 0) {
    console.log('\n--- Files with Issues ---\n')

    // Group by issue type for better readability
    const byType = {}
    for (const detail of results.details) {
      for (const issue of detail.issues) {
        if (!byType[issue.type]) byType[issue.type] = []
        byType[issue.type].push({
          file: detail.file,
          ...issue
        })
      }
    }

    for (const [type, items] of Object.entries(byType)) {
      console.log(`\n[${type}] ${ISSUES[type].description}:`)
      for (const item of items.slice(0, 20)) { // Limit to first 20
        console.log(`  - ${item.file}`)
        if (item.lines) {
          for (const line of item.lines.slice(0, 2)) {
            console.log(`      ${line}...`)
          }
        }
      }
      if (items.length > 20) {
        console.log(`  ... and ${items.length - 20} more`)
      }
    }
  }

  // Summary recommendations
  console.log('\n--- Recommendations ---')
  if (results.issuesByType.DUPLICATE_H1 > 0) {
    console.log(`\n1. DUPLICATE_H1 (${results.issuesByType.DUPLICATE_H1} files):`)
    console.log('   Remove <h1> tags from document components - PageHeader already renders the title.')
    console.log('   Pattern to follow: See CoolArchive.js or PageOfCool.js')
  }
  if (results.issuesByType.MISSING_USE_IS_MOBILE > 0) {
    console.log(`\n2. MISSING_USE_IS_MOBILE (${results.issuesByType.MISSING_USE_IS_MOBILE} files):`)
    console.log('   Add: import { useIsMobile } from "../../hooks/useMediaQuery"')
    console.log('   Then: const isMobile = useIsMobile()')
    console.log('   Use for responsive padding, margins, and widths.')
  }

  console.log('\n')
}

// JSON output for programmatic use
function printJson(results) {
  console.log(JSON.stringify(results, null, 2))
}

// Extract component type to URL mapping (for screenshot capability)
function getTestUrls() {
  // Map of component types to test URLs
  return {
    'cool_archive': '/title/Cool%20Archive',
    'page_of_cool': '/title/Page%20of%20Cool',
    'guest_front_page': '/',
    'editor_endorsements': '/title/Editor%20Endorsements',
    'everything_statistics': '/title/Everything%20Statistics',
    'voting_experience_system': '/title/voting%2Fexperience%20system',
    'e2_sperm_counter': '/title/E2%20Sperm%20Counter',
    'new_writeups': '/title/New%20Writeups',
    'settings': '/title/User%20Settings',
    'message_inbox': '/title/Message%20Inbox'
  }
}

// Print list of files that need H1 removal (most actionable)
function printH1List(results) {
  console.log('\n=== Files with Duplicate H1 (Priority Fix) ===\n')
  const h1Files = results.details
    .filter(d => d.issues.some(i => i.type === 'DUPLICATE_H1'))
    .map(d => d.file)
    .sort()

  for (const file of h1Files) {
    console.log(file)
  }
  console.log(`\nTotal: ${h1Files.length} files`)
}

// Generate markdown report
function generateMarkdown(results) {
  const now = new Date().toISOString().split('T')[0]

  // Group files by issue type
  const h1Files = results.details
    .filter(d => d.issues.some(i => i.type === 'DUPLICATE_H1'))
    .map(d => d.file)
    .sort()

  const missingMobileFiles = results.details
    .filter(d => d.issues.some(i => i.type === 'MISSING_USE_IS_MOBILE'))
    .map(d => d.file)
    .sort()

  const hardcodedPaddingFiles = results.details
    .filter(d => d.issues.some(i => i.type === 'HARDCODED_PADDING'))
    .map(d => d.file)
    .sort()

  const hardcodedWidthFiles = results.details
    .filter(d => d.issues.some(i => i.type === 'HARDCODED_MAX_WIDTH'))
    .map(d => d.file)
    .sort()

  let md = `# Mobile Optimization Audit Report

**Generated:** ${now}
**Tool:** \`node tools/mobile-audit.js\`

## Summary

| Metric | Count |
|--------|-------|
| Total document components | ${results.totalFiles} |
| Components with issues | ${results.filesWithIssues} |
| Components passing | ${results.totalFiles - results.filesWithIssues} |
| Pass rate | ${Math.round((results.totalFiles - results.filesWithIssues) / results.totalFiles * 100)}% |

## Issues by Type

| Issue Type | Count | Severity | Description |
|------------|-------|----------|-------------|
| DUPLICATE_H1 | ${results.issuesByType.DUPLICATE_H1 || 0} | Warning | Component renders its own H1 when PageHeader already provides one |
| MISSING_USE_IS_MOBILE | ${results.issuesByType.MISSING_USE_IS_MOBILE || 0} | Info | No responsive hook for mobile-specific styling |
| HARDCODED_PADDING | ${results.issuesByType.HARDCODED_PADDING || 0} | Info | Fixed padding that doesn't adapt to mobile |
| HARDCODED_MAX_WIDTH | ${results.issuesByType.HARDCODED_MAX_WIDTH || 0} | Info | Fixed maxWidth that doesn't adapt to mobile |

---

## Priority 1: Duplicate H1 Tags (${h1Files.length} files)

These components render their own \`<h1>\` tag, creating duplicate headings since PageHeader already renders the page title. This is a **user-visible issue** that affects both UX and accessibility.

**Fix pattern:**
1. Remove the \`<h1>\` element from the component
2. Keep any intro/description text as a \`<p>\` element
3. Remove unused \`headerStyle\` and \`titleStyle\` constants

**Example (from CoolArchive.js):**
\`\`\`jsx
// BEFORE - duplicate H1
<div style={headerStyle}>
  <h1 style={titleStyle}>Cool Archive</h1>
  <p style={introStyle}>Description text...</p>
</div>

// AFTER - no duplicate H1
<p style={introStyle}>Description text...</p>
\`\`\`

### Files to fix:

| File | Status |
|------|--------|
`

  for (const file of h1Files) {
    md += `| ${file} | ⬜ Pending |\n`
  }

  md += `
---

## Priority 2: Hardcoded Dimensions (${hardcodedPaddingFiles.length + hardcodedWidthFiles.length} files)

These components have hardcoded padding or maxWidth that doesn't adapt to mobile viewports.

**Fix pattern:**
\`\`\`jsx
// Add import
import { useIsMobile } from '../../hooks/useMediaQuery'

// Add hook
const isMobile = useIsMobile()

// Update styles
const containerStyle = {
  padding: isMobile ? '0' : '20px',
  maxWidth: isMobile ? '100%' : '1200px',
  margin: '0 auto'
}
\`\`\`

### Files with hardcoded padding:

`

  for (const file of hardcodedPaddingFiles) {
    md += `- [ ] ${file}\n`
  }

  md += `
### Files with hardcoded maxWidth:

`

  for (const file of hardcodedWidthFiles) {
    md += `- [ ] ${file}\n`
  }

  md += `
---

## Priority 3: Missing useIsMobile Hook (${missingMobileFiles.length} files)

These components have inline styles but don't use the \`useIsMobile\` hook for responsive behavior. Lower priority since CSS media queries may handle basic cases.

<details>
<summary>Click to expand full list (${missingMobileFiles.length} files)</summary>

`

  for (const file of missingMobileFiles) {
    md += `- ${file}\n`
  }

  md += `
</details>

---

## How to Use This Report

1. **Start with Priority 1** (Duplicate H1s) - these are user-visible issues
2. **Test visually** using \`node tools/browser-debug.js screenshot-mobile [url]\`
3. **Mark items complete** by changing ⬜ to ✅ in this document
4. **Re-run audit** periodically: \`node tools/mobile-audit.js --markdown > docs/mobile-audit.md\`

## Related Tools

- \`node tools/mobile-audit.js\` - Run full audit
- \`node tools/mobile-audit.js --h1-only\` - List only duplicate H1 files
- \`node tools/mobile-audit.js --json\` - JSON output for scripting
- \`node tools/browser-debug.js screenshot-mobile [url]\` - Take mobile screenshot
- \`node tools/browser-debug.js screenshot-as-mobile [user] [url]\` - Mobile screenshot as user
`

  return md
}

// Main
const args = process.argv.slice(2)
const jsonOutput = args.includes('--json')
const h1Only = args.includes('--h1-only')
const markdownOutput = args.includes('--markdown')

const results = audit()

if (jsonOutput) {
  printJson(results)
} else if (h1Only) {
  printH1List(results)
} else if (markdownOutput) {
  console.log(generateMarkdown(results))
} else {
  printResults(results)
}

process.exit(results.filesWithIssues > 0 ? 1 : 0)
